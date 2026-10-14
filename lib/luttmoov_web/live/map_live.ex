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

    {:ok, socket}
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id="map" phx-hook=".Map" phx-update="ignore" class="h-dvh w-full"></div>
    <Layouts.flash_group flash={@flash} />

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Map">
      // Hamburg city centre
      const CENTER = [53.55, 10.0]
      const ZOOM = 12
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

          // Replaces all markers, so a reconnect (which mounts again and
          // pushes again) does not draw duplicates.
          this.handleEvent("stations", ({stations}) => {
            this.stations.clearLayers()

            for (const station of stations) {
              L.circleMarker([station.lat, station.lon], STATION_STYLE)
                .bindPopup(popupContent(station))
                .addTo(this.stations)
            }
          })
        },

        destroyed() {
          this.map.remove()
        },
      }
    </script>
    """
  end
end
