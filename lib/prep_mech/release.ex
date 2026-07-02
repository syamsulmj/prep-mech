defmodule PrepMech.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :prep_mech

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seeds demo data by evaluating `priv/repo/seeds.exs`.

  Run this from a RUNNING node — a remote console on the deployed server:

      /app/bin/prep_mech remote
      iex> PrepMech.Release.seed()

  The seeds drive the `Orders` context, which broadcasts over `Phoenix.PubSub`,
  so the app's supervision tree (Repo + PubSub) must already be started — which it
  is on the live node. `bin/prep_mech eval` will NOT work for seeds, because it
  boots a bare node without the supervision tree.
  """
  def seed do
    load_app()
    Code.eval_file(Application.app_dir(@app, "priv/repo/seeds.exs"))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
