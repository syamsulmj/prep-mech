defmodule PrepMech.Repo do
  use Ecto.Repo,
    otp_app: :prep_mech,
    adapter: Ecto.Adapters.Postgres
end
