defmodule Luttmoov.Geofox do
  @moduledoc """
  Thin layer over `geofox_ex`.

  Builds the API client from application config and converts between
  Geofox coordinates (`x` = longitude, `y` = latitude) and the
  `[lat, lng]` pairs Leaflet uses, so the rest of the app never deals
  with the API's conventions.

  Configured under `config :luttmoov, Luttmoov.Geofox`:

    * `:user`, `:password` - API credentials (set in `config/runtime.exs`)
    * `:req_options` - extra Req options, e.g. a `Req.Test` plug in tests
  """

  @typedoc "A `[lat, lng]` pair, as used by Leaflet."
  @type latlng :: [float()]

  @doc """
  Returns a Geofox client built from application config.
  """
  @spec client() :: Req.Request.t()
  def client do
    :luttmoov
    |> Application.get_env(__MODULE__, [])
    |> Keyword.take([:user, :password, :req_options])
    |> Geofox.new()
  end

  @doc """
  Converts a Geofox coordinate to `[lat, lng]`.

  Returns `nil` for a missing coordinate.

  ## Examples

      iex> Luttmoov.Geofox.to_latlng(%{"x" => 9.993, "y" => 53.552, "type" => "EPSG_4326"})
      [53.552, 9.993]

      iex> Luttmoov.Geofox.to_latlng(nil)
      nil

  """
  @spec to_latlng(map() | nil) :: latlng() | nil
  def to_latlng(%{"x" => x, "y" => y}), do: [y, x]
  def to_latlng(nil), do: nil

  @doc """
  Builds a Geofox bounding box from its south-west and north-east corners,
  each given as `[lat, lng]`.

  ## Examples

      iex> Luttmoov.Geofox.bbox([53.4, 9.7], [53.7, 10.3])
      %{
        "lowerLeft" => %{"x" => 9.7, "y" => 53.4, "type" => "EPSG_4326"},
        "upperRight" => %{"x" => 10.3, "y" => 53.7, "type" => "EPSG_4326"}
      }

  """
  @spec bbox(latlng(), latlng()) :: map()
  def bbox([south, west], [north, east]) do
    Geofox.bounding_box(Geofox.coordinate(west, south), Geofox.coordinate(east, north))
  end
end
