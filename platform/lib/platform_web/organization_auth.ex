defmodule PlatformWeb.OrganizationAuth do
  @moduledoc """
  Scope assignment for the single-tenant, self-hosted platform.

  There are no user accounts and no login: every browser request operates as
  the bootstrap organization created at startup (`Platform.Bootstrap`). The
  agent API key — checked on the agent WebSocket — is the system's credential.
  Protecting the web dashboard is a deployment concern: bind it to a private
  interface or front it with your own auth proxy (see README, Security).
  """

  use PlatformWeb, :verified_routes

  import Plug.Conn

  alias Platform.Account.Scope
  alias Platform.Bootstrap

  @doc "Plug: assigns the bootstrap organization as the current scope."
  def assign_bootstrap_scope(conn, _opts) do
    assign(conn, :current_scope, Scope.for_organization(Bootstrap.organization!()))
  end

  @doc """
  LiveView on_mount hook: assigns the bootstrap organization as the current
  scope.

      live_session :bootstrap,
        on_mount: [{PlatformWeb.OrganizationAuth, :bootstrap_scope}] do
  """
  def on_mount(:bootstrap_scope, _params, _session, socket) do
    {:cont,
     Phoenix.Component.assign(
       socket,
       :current_scope,
       Scope.for_organization(Bootstrap.organization!())
     )}
  end

  @doc "Where the root URL lands once an API key exists."
  def signed_in_path(_conn_or_socket), do: ~p"/portal"
end
