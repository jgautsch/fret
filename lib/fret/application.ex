defmodule Fret.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FretWeb.Telemetry,
      Fret.Repo,
      {DNSCluster, query: Application.get_env(:fret, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Fret.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Fret.Finch},
      # Start a worker by calling: Fret.Worker.start_link(arg)
      # {Fret.Worker, arg},
      # Start to serve requests, typically the last entry
      FretWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fret.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FretWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
