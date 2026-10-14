defmodule Luttmoov.Transit do
  @moduledoc """
  The transit context: HVV stations (and, later, vehicles).
  """

  import Ecto.Query

  alias Luttmoov.Repo
  alias Luttmoov.Transit.Station

  # 6 columns x 500 rows = 3,000 bind parameters, well below SQLite's limit.
  @insert_chunk_size 500

  @doc """
  Returns all stations as plain maps, ready to push to the map.
  """
  @spec list_stations() :: [map()]
  def list_stations do
    Station
    |> order_by(:id)
    |> select([s], map(s, [:id, :name, :city, :lat, :lon, :vehicle_types]))
    |> Repo.all()
  end

  @doc """
  Fetches all stations from the Geofox API and replaces the `stations`
  table with them in a single transaction.

  Entries that are marked `exists: false` or fail `Station.changeset/2`
  (e.g. no name or no coordinate) are skipped. An empty result leaves the
  table untouched.

  Returns `{:ok, count}` with the number of stored stations.
  """
  @spec sync_stations() :: {:ok, non_neg_integer()} | {:error, term()}
  def sync_stations do
    with {:ok, %{"stations" => entries}} <- Geofox.list_stations(Luttmoov.Geofox.client()),
         [_ | _] = rows <- to_rows(entries) do
      replace_stations(rows)
    else
      [] -> {:error, :no_stations}
      {:ok, response} -> {:error, {:unexpected_response, response}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_rows(entries) do
    entries
    |> Enum.reject(&(&1["exists"] == false))
    |> Enum.map(&Station.changeset(%Station{}, entry_attrs(&1)))
    |> Enum.filter(& &1.valid?)
    |> Enum.map(&row/1)
    |> Enum.uniq_by(& &1.id)
  end

  defp entry_attrs(entry) do
    {lat, lon} =
      case Luttmoov.Geofox.to_latlng(entry["coordinate"]) do
        [lat, lon] -> {lat, lon}
        nil -> {nil, nil}
      end

    %{
      id: entry["id"],
      name: entry["name"],
      city: entry["city"],
      lat: lat,
      lon: lon,
      vehicle_types: entry["vehicleTypes"] || []
    }
  end

  defp row(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.take([:id, :name, :city, :lat, :lon, :vehicle_types])
  end

  defp replace_stations(rows) do
    Repo.transaction(fn ->
      Repo.delete_all(Station)

      rows
      |> Enum.chunk_every(@insert_chunk_size)
      |> Enum.each(&Repo.insert_all(Station, &1))

      length(rows)
    end)
  end
end
