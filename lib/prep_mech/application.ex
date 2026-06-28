defmodule PrepMech.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PrepMechWeb.Telemetry,
      PrepMech.Repo,
      {DNSCluster, query: Application.get_env(:prep_mech, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrepMech.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: PrepMech.Finch},
      # Start a worker by calling: PrepMech.Worker.start_link(arg)
      # {PrepMech.Worker, arg},
      # Start to serve requests, typically the last entry
      PrepMechWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PrepMech.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PrepMechWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
