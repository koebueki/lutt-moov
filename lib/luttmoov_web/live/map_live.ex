defmodule LuttmoovWeb.MapLive do
  use LuttmoovWeb, :live_view

  @impl true
  @spec mount(any(), any(), any()) :: {:ok, any()}
  def mount(_params, _session, socket) do
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

      export default {
        mounted() {
          this.map = L.map(this.el, {preferCanvas: true}).setView(CENTER, ZOOM)

          L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            maxZoom: 19,
            attribution:
              '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
          }).addTo(this.map)
        },

        destroyed() {
          this.map.remove()
        },
      }
    </script>
    """
  end
end
