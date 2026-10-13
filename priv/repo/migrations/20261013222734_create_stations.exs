defmodule Luttmoov.Repo.Migrations.CreateStations do
  use Ecto.Migration

  def change do
    create table(:stations, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :city, :string
      add :lat, :float, null: false
      add :lon, :float, null: false
      add :vehicle_types, {:array, :string}, null: false, default: []
    end
  end
end
