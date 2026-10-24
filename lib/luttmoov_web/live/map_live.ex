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

    {:ok,
     assign(socket,
       query: "",
       results: [],
       maptiler_key: Application.get_env(:luttmoov, :maptiler_key)
     )}
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
      <div
        id="map"
        phx-hook=".Map"
        phx-update="ignore"
        data-maptiler-key={@maptiler_key}
        class="isolate min-h-0 flex-1"
      >
      </div>
    </div>
    <Layouts.flash_group flash={@flash} />

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Map">
      // Hamburg city centre
      const CENTER = [53.55, 10.0]
      const ZOOM = 12
      const FOCUS_ZOOM = 16
      // Any MapTiler map ID, see https://cloud.maptiler.com/maps/
      const MAP_STYLE = "streets-v2"
      const STATION_STYLE = {
        radius: 4,
        color: "#1e3a8a",
        weight: 1,
        fillColor: "#3b82f6",
        fillOpacity: 0.8,
      }

      const DEPARTURES_REFRESH_MS = 30_000

      // Station names and departures come from the API, so they go in as
      // text, never HTML.
      function textElement(tag, className, text) {
        const el = document.createElement(tag)
        el.className = className
        el.textContent = text
        return el
      }

      function departureRow({line, direction, time, minutes, delay, cancelled}) {
        const due = cancelled ? "cancelled" : minutes <= 0 ? "now" : `${minutes} min`
        const dueClass = cancelled || delay > 0 ? "text-error font-semibold" : "font-semibold"

        const row = document.createElement("li")
        row.className = "flex items-center gap-2 py-0.5"
        row.append(
          textElement("span", "badge badge-sm badge-neutral shrink-0", line ?? "?"),
          textElement("span", "min-w-0 flex-1 truncate", direction ?? ""),
          textElement("span", "shrink-0 tabular-nums opacity-60", time ?? ""),
          textElement("span", `w-16 shrink-0 text-right tabular-nums ${dueClass}`, due),
        )
        return row
      }

      export default {
        mounted() {
          this.map = L.map(this.el, {preferCanvas: true}).setView(CENTER, ZOOM)

          // 512px tiles with zoomOffset -1 need a quarter of the requests of
          // 256px ones, and MapTiler bills per request. {r} adds @2x on HiDPI.
          const key = encodeURIComponent(this.el.dataset.maptilerKey)
          L.tileLayer(`https://api.maptiler.com/maps/${MAP_STYLE}/{z}/{x}/{y}{r}.png?key=${key}`, {
            tileSize: 512,
            zoomOffset: -1,
            minZoom: 1,
            maxZoom: 20,
            crossOrigin: true,
            attribution:
              '<a href="https://www.maptiler.com/copyright/" target="_blank">&copy; MapTiler</a> ' +
              '<a href="https://www.openstreetmap.org/copyright" target="_blank">&copy; OpenStreetMap contributors</a>',
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
                .bindPopup("")
                .on("popupopen", ({popup}) => this.showDepartures(popup, station))
                .on("popupclose", () => this.stopDepartures())
                .addTo(this.stations)

              this.markers.set(station.id, marker)
            }
          })

          this.handleEvent("focus_station", ({id, lat, lon}) => {
            this.map.flyTo([lat, lon], FOCUS_ZOOM)
            this.map.once("moveend", () => this.markers.get(id)?.openPopup())
          })
        },

        // Fills the popup with the station's departures and refreshes them
        // until the popup closes.
        showDepartures(popup, station) {
          this.stopDepartures()

          const status = textElement("p", "mt-1 opacity-60", "Loading departures…")
          const list = textElement("ul", "mt-1", "")
          const content = document.createElement("div")
          content.className = "w-72 max-w-full"
          content.append(textElement("strong", "", station.name), status, list)
          popup.setContent(content)

          const abort = new AbortController()
          const url = `/api/stations/${encodeURIComponent(station.id)}/departures`

          const load = async () => {
            try {
              const response = await fetch(url, {
                signal: abort.signal,
                headers: {accept: "application/json"},
              })
              if (!response.ok) throw new Error(`HTTP ${response.status}`)

              const {departures} = await response.json()
              list.replaceChildren(...departures.map(departureRow))
              status.textContent = "No departures in the next hour"
              status.hidden = departures.length > 0
            } catch (error) {
              if (error.name === "AbortError") return
              list.replaceChildren()
              status.textContent = "Departures are unavailable right now"
              status.hidden = false
            }
            // Re-layout, since the content changed size.
            popup.update()
          }

          load()
          this.departures = {abort, timer: setInterval(load, DEPARTURES_REFRESH_MS)}
        },

        stopDepartures() {
          if (!this.departures) return
          this.departures.abort.abort()
          clearInterval(this.departures.timer)
          this.departures = null
        },

        destroyed() {
          this.stopDepartures()
          this.map.remove()
        },
      }
    </script>
    """
  end

  defp show_results, do: JS.show(to: "#station-results")
  defp hide_results, do: JS.hide(to: "#station-results")
end
