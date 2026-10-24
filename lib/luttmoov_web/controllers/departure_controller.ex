defmodule LuttmoovWeb.DepartureController do
  use LuttmoovWeb, :controller

  require Logger

  alias Luttmoov.Transit

  @doc """
  Lists the next departures from a station, fetched live from Geofox.

  Responds with 404 for an unknown station and 502 when Geofox fails.
  """
  def index(conn, %{"station_id" => station_id}) do
    with %{} = station <- Transit.get_station(station_id),
         {:ok, departures} <- Transit.list_departures(station) do
      render(conn, :index, departures: departures)
    else
      nil ->
        error(conn, :not_found)

      {:error, reason} ->
        Logger.warning("Departures for #{station_id} failed: #{inspect(reason)}")
        error(conn, :bad_gateway)
    end
  end

  defp error(conn, status) do
    conn
    |> put_status(status)
    |> put_view(json: LuttmoovWeb.ErrorJSON)
    |> render(:"#{Plug.Conn.Status.code(status)}")
  end
end
