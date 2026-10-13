defmodule Luttmoov.Transit.Station do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "stations" do
    field :name, :string
    field :city, :string
    field :lat, :float
    field :lon, :float
    field :vehicle_types, {:array, :string}, default: []
  end

  @doc false
  def changeset(station, attrs) do
    station
    |> cast(attrs, [:id, :name, :city, :lat, :lon, :vehicle_types])
    |> validate_required([:id, :name, :lat, :lon])
  end
end
