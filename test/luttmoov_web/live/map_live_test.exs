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

  describe "toolbar" do
    setup do
      Repo.insert!(%Station{
        id: "Master:1",
        name: "Hauptbahnhof",
        city: "Hamburg",
        lat: 53.553,
        lon: 10.006
      })

      Repo.insert!(%Station{
        id: "Master:2",
        name: "Hammer Kirche",
        city: "Hamburg",
        lat: 53.555,
        lon: 10.051
      })

      :ok
    end

    test "renders the title, search box and theme toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "header.navbar", "Lütt Mööv")
      assert has_element?(view, "#station-search input[name=q]")
      assert has_element?(view, "header [data-phx-theme=dark]")
    end

    test "lists matching stations as you type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#station-search", q: "hamm") |> render_change()

      assert has_element?(view, "#station-results button", "Hammer Kirche")
      refute has_element?(view, "#station-results button", "Hauptbahnhof")
    end

    test "picking a result focuses it on the map and closes the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#station-search", q: "ha") |> render_change()
      view |> element("#station-results button", "Hammer Kirche") |> render_click()

      assert_push_event(view, "focus_station", %{id: "Master:2", lat: 53.555, lon: 10.051})
      refute has_element?(view, "#station-results")
      assert has_element?(view, "#station-search input[value='Hammer Kirche']")
    end

    test "submitting focuses the top result", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#station-search", q: "ha") |> render_change()
      view |> form("#station-search") |> render_submit()

      assert_push_event(view, "focus_station", %{id: "Master:2"})
    end

    test "submitting with no results does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#station-search", q: "nowhere") |> render_change()
      view |> form("#station-search") |> render_submit()

      refute_push_event(view, "focus_station", %{})
    end
  end
end
