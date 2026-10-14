defmodule Luttmoov.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      Enum.reject(
        [
          LuttmoovWeb.Telemetry,
          Luttmoov.Repo,
          {DNSCluster, query: Application.get_env(:luttmoov, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: Luttmoov.PubSub},
          station_sync(),
          # Start a worker by calling: Luttmoov.Worker.start_link(arg)
          # {Luttmoov.Worker, arg},
          # Start to serve requests, typically the last entry
          LuttmoovWeb.Endpoint
        ],
        &is_nil/1
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Luttmoov.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Fills the stations table on first boot. A one-off, temporary task: a
  # failed sync is logged and does not affect the rest of the app.
  defp station_sync do
    if Application.get_env(:luttmoov, :sync_stations_on_boot, true) do
      {Task, &Luttmoov.Transit.sync_stations_if_empty/0}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LuttmoovWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
