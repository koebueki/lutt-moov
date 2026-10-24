defmodule Luttmoov.Transit do
  @moduledoc """
  The transit context: HVV stations (and, later, vehicles).
  """

  import Ecto.Query
  require Logger

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
  Returns up to `limit` stations whose name contains `term`, names that
  start with it first. Matching ignores case for ASCII letters only (SQLite
  `LIKE`). A blank term returns no stations.
  """
  @spec search_stations(String.t(), pos_integer()) :: [map()]
  def search_stations(term, limit \\ 8) do
    case String.trim(term) do
      "" ->
        []

      term ->
        escaped = escape_like(term)
        contains = "%" <> escaped <> "%"
        prefix = escaped <> "%"

        Station
        |> where([s], fragment("? LIKE ? ESCAPE '\\'", s.name, ^contains))
        |> order_by([s], desc: fragment("? LIKE ? ESCAPE '\\'", s.name, ^prefix), asc: s.name)
        |> limit(^limit)
        |> select([s], map(s, [:id, :name, :city, :lat, :lon]))
        |> Repo.all()
    end
  end

  defp escape_like(term), do: String.replace(term, ~r/[\\%_]/, "\\\\\\0")

  @doc """
  Returns the station with the given id, or `nil`.
  """
  @spec get_station(String.t()) :: %Station{} | nil
  def get_station(id), do: Repo.get(Station, id)

  @doc """
  Fetches the next departures from `station` within the next hour, with
  realtime delays, from the Geofox API.

  Each departure is a map with:

    * `:line`, `:direction` - e.g. `"U3"`, `"Barmbek"`
    * `:time` - planned departure as `"HH:MM"` (local time), or `nil`
    * `:minutes` - minutes until departure, including the delay
    * `:delay` - delay in whole minutes
    * `:cancelled` - whether the departure is cancelled
    * `:platform` - the realtime platform if known, else the planned one
  """
  @spec list_departures(%Station{}) :: {:ok, [map()]} | {:error, term()}
  def list_departures(%Station{id: id, name: name}) do
    station = %{"id" => id, "name" => name, "type" => "STATION"}
    # GTI resolves "heute"/"jetzt" in Hamburg time, so no time zone handling here.
    now = Geofox.gti_time("heute", "jetzt")

    case Geofox.departure_list(Luttmoov.Geofox.client(), station, now,
           max_list: 10,
           max_time_offset: 60,
           use_realtime: true
         ) do
      {:ok, %{"returnCode" => "OK"} = response} ->
        reference = parse_time(response["time"])
        {:ok, Enum.map(response["departures"] || [], &departure(&1, reference))}

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # `timeOffset` is in minutes from the response's `time`, `delay` in seconds.
  defp departure(entry, reference) do
    offset = entry["timeOffset"] || 0
    delay = div(entry["delay"] || 0, 60)

    %{
      line: get_in(entry, ["line", "name"]),
      direction: get_in(entry, ["line", "direction"]),
      time: reference && reference |> Time.add(offset, :minute) |> Calendar.strftime("%H:%M"),
      minutes: offset + delay,
      delay: delay,
      cancelled: entry["cancelled"] == true,
      platform: entry["realtimePlatform"] || entry["platform"]
    }
  end

  defp parse_time(%{"time" => time}) when is_binary(time) do
    case Time.from_iso8601(time <> ":00") do
      {:ok, time} -> time
      {:error, _} -> nil
    end
  end

  defp parse_time(_), do: nil

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

  @doc """
  Runs `sync_stations/0` if the `stations` table is empty, logging the
  outcome. Started at boot by `Luttmoov.Application`.
  """
  @spec sync_stations_if_empty() :: :ok
  def sync_stations_if_empty do
    if Repo.exists?(Station) do
      :ok
    else
      case sync_stations() do
        {:ok, count} -> Logger.info("Synced #{count} stations from Geofox")
        {:error, reason} -> Logger.warning("Station sync failed: #{inspect(reason)}")
      end
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
