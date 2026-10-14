defmodule Luttmoov.Transit.StationTest do
  use Luttmoov.DataCase

  alias Luttmoov.Transit.Station

  @valid_attrs %{
    id: "Master:10950",
    name: "Jungfernstieg",
    city: "Hamburg",
    lat: 53.552,
    lon: 9.993,
    vehicle_types: ["U_BAHN", "S_BAHN"]
  }

  describe "changeset/2" do
    test "is valid with all fields" do
      assert Station.changeset(%Station{}, @valid_attrs).valid?
    end

    test "is valid without optional city and vehicle_types" do
      attrs = Map.drop(@valid_attrs, [:city, :vehicle_types])
      assert Station.changeset(%Station{}, attrs).valid?
    end

    test "requires id, name, lat and lon" do
      changeset = Station.changeset(%Station{}, %{})

      assert %{
               id: ["can't be blank"],
               name: ["can't be blank"],
               lat: ["can't be blank"],
               lon: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  test "vehicle_types round-trips through the database as a list" do
    %Station{} |> Station.changeset(@valid_attrs) |> Repo.insert!()

    assert %Station{vehicle_types: ["U_BAHN", "S_BAHN"]} = Repo.get!(Station, "Master:10950")
  end

  test "vehicle_types defaults to an empty list" do
    @valid_attrs
    |> Map.delete(:vehicle_types)
    |> then(&Station.changeset(%Station{}, &1))
    |> Repo.insert!()

    assert %Station{vehicle_types: []} = Repo.get!(Station, "Master:10950")
  end
end
