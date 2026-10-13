defmodule Luttmoov.Repo do
  use Ecto.Repo,
    otp_app: :luttmoov,
    adapter: Ecto.Adapters.SQLite3
end
