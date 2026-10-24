defmodule LuttmoovWeb.DepartureJSON do
  @doc """
  Renders a list of departures.
  """
  def index(%{departures: departures}), do: %{departures: departures}
end
