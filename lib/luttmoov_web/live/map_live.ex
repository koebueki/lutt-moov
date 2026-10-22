defmodule LuttmoovWeb.MapLive do
  use LuttmoovWeb, :live_view

  alias Luttmoov.Transit

  @impl true
  @spec mount(any(), any(), any()) :: {:ok, any()}
  def mount(_params, _session, socket) do
    # Stations go to the client once per connection; they are not kept in
    # assigns, so the LiveView process does not hold thousands of rows.
    socket =
      if connected?(socket) do
        push_event(socket, "stations", %{stations: Transit.list_stations()})
      else
        socket
      end

    {:ok, assign(socket, query: "", results: [])}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign(socket, query: query, results: Transit.search_stations(query))}
  end

  def handle_event("select_station", %{"id" => id}, socket) do
    {:noreply, focus_station(socket, Enum.find(socket.assigns.results, &(&1.id == id)))}
  end

  # Enter in the search box picks the top result.
  def handle_event("select_first", _params, socket) do
    {:noreply, focus_station(socket, List.first(socket.assigns.results))}
  end

  defp focus_station(socket, nil), do: socket

  defp focus_station(socket, station) do
    socket
    |> assign(query: station.name, results: [])
    |> push_event("focus_station", Map.take(station, [:id, :lat, :lon]))
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="flex h-dvh flex-col">
      <header class="navbar gap-2 bg-base-100 px-4 shadow-sm">
        <a href={~p"/"} class="flex shrink-0 items-center gap-2">
          <img src={~p"/images/favicon.svg"} class="size-8" alt="" />
          <span class="hidden text-lg font-semibold sm:inline">Lütt Mööv</span>
        </a>

        <div class="relative flex-1 sm:max-w-sm sm:mx-auto" phx-click-away={hide_results()}>
          <form id="station-search" phx-change="search" phx-submit="select_first">
            <label class="input w-full">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input
                type="search"
                name="q"
                value={@query}
                placeholder="Search stations"
                aria-label="Search stations"
                autocomplete="off"
                phx-debounce="200"
                phx-focus={show_results()}
              />
            </label>
          </form>

          <ul
            :if={@results != []}
            id="station-results"
            class="menu absolute inset-x-0 top-full z-10 mt-1 w-full rounded-box bg-base-100 shadow-lg"
          >
            <li :for={station <- @results}>
              <button type="button" phx-click="select_station" phx-value-id={station.id}>
                {station.name}
                <span :if={station.city} class="text-xs opacity-60">{station.city}</span>
              </button>
            </li>
          </ul>
        </div>

        <div class="shrink-0">
          <Layouts.theme_toggle />
        </div>
      </header>

      <%!-- isolate keeps Leaflet's z-indexed panes from covering the search results --%>
      <div id="map" phx-hook=".Map" phx-update="ignore" class="isolate min-h-0 flex-1"></div>
    </div>
    <Layouts.flash_group flash={@flash} />

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Map">
      // Hamburg city centre
      const CENTER = [53.55, 10.0]
      const ZOOM = 12
      const FOCUS_ZOOM = 16
      const STATION_STYLE = {
        radius: 4,
        color: "#1e3a8a",
        weight: 1,
        fillColor: "#3b82f6",
        fillOpacity: 0.8,
      }

      // Station names come from the API, so they go in as text, never HTML.
      function popupContent(station) {
        const el = document.createElement("span")
        el.textContent = station.name
        return el
      }

      export default {
        mounted() {
          this.map = L.map(this.el, {preferCanvas: true}).setView(CENTER, ZOOM)

          L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            maxZoom: 19,
            attribution:
              '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
          }).addTo(this.map)

          this.stations = L.layerGroup().addTo(this.map)
          this.markers = new Map()

          // Replaces all markers, so a reconnect (which mounts again and
          // pushes again) does not draw duplicates.
          this.handleEvent("stations", ({stations}) => {
            this.stations.clearLayers()
            this.markers.clear()

            for (const station of stations) {
              const marker = L.circleMarker([station.lat, station.lon], STATION_STYLE)
                .bindPopup(popupContent(station))
                .addTo(this.stations)

              this.markers.set(station.id, marker)
            }
          })

          this.handleEvent("focus_station", ({id, lat, lon}) => {
            this.map.flyTo([lat, lon], FOCUS_ZOOM)
            this.map.once("moveend", () => this.markers.get(id)?.openPopup())
          })
        },

        destroyed() {
          this.map.remove()
        },
      }
    </script>
    """
  end

  defp show_results, do: JS.show(to: "#station-results")
  defp hide_results, do: JS.hide(to: "#station-results")
end
