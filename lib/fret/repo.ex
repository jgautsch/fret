defmodule Fret.Repo do
  use Ecto.Repo,
    otp_app: :fret,
    adapter: Ecto.Adapters.Postgres
end
