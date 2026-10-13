defmodule LuttmoovWeb.PageController do
  use LuttmoovWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
