defmodule LuttmoovWeb.MapLiveTest do
  use LuttmoovWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET / renders the map container", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#map[phx-hook][phx-update=ignore]")
  end
end
