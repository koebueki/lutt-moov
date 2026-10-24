defmodule LuttmoovWeb.Router do
  use LuttmoovWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LuttmoovWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LuttmoovWeb do
    pipe_through :browser

    live "/", MapLive
  end

  scope "/api", LuttmoovWeb do
    pipe_through :api

    get "/stations/:station_id/departures", DepartureController, :index
  end
end
