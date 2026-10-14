defmodule LuttmoovWeb.MapLiveTest do
  use LuttmoovWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Luttmoov.Repo
  alias Luttmoov.Transit.Station

  test "GET / renders the map container", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#map[phx-hook][phx-update=ignore]")
  end

  test "pushes stations to the map on connect", %{conn: conn} do
    %Station{}
    |> Station.changeset(%{
      id: "Master:10950",
      name: "Jungfernstieg",
      city: "Hamburg",
      lat: 53.552,
      lon: 9.993,
      vehicle_types: ["U_BAHN", "S_BAHN"]
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/")

    assert_push_event(view, "stations", %{
      stations: [
        %{
          id: "Master:10950",
          name: "Jungfernstieg",
          lat: 53.552,
          lon: 9.993,
          vehicle_types: ["U_BAHN", "S_BAHN"]
        }
      ]
    })
  end

  test "pushes an empty list when there are no stations", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert_push_event(view, "stations", %{stations: []})
  end
end
