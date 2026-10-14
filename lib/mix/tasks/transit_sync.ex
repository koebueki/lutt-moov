defmodule Mix.Tasks.Transit.Sync do
  @shortdoc "Syncs HVV stations from the Geofox API"

  @moduledoc """
  Fetches all HVV stations from the Geofox API and replaces the
  `stations` table with them.

      $ mix transit.sync

  Needs `GEOFOX_USER` and `GEOFOX_PASSWORD` (see the README).
  """

  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    # This task syncs itself; skip the boot-time sync so the API is only
    # called once.
    Application.put_env(:luttmoov, :sync_stations_on_boot, false)
    Mix.Task.run("app.start")

    case Luttmoov.Transit.sync_stations() do
      {:ok, count} -> Mix.shell().info("Synced #{count} stations.")
      {:error, reason} -> Mix.raise("Station sync failed: #{inspect(reason)}")
    end
  end
end
