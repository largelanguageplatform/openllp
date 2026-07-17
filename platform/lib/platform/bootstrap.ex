defmodule Platform.Bootstrap do
  @moduledoc """
  Creates the single local organization this self-hosted instance operates as.

  The open-source platform is single-tenant: there are no user accounts and no
  login. Every web request runs in the scope of this bootstrap organization
  (see `PlatformWeb.OrganizationAuth.assign_bootstrap_scope/2`); the only
  credential in the system is the agent API key.

  Runs synchronously at application start, after the Repo (and after release
  migrations, which `bin/server` applies before boot). Idempotent across
  restarts; the organization name is configurable via `BOOTSTRAP_ORG_NAME`.
  """

  import Ecto.Query, only: [from: 2]

  alias Platform.Account.Organization
  alias Platform.Repo

  @doc false
  def child_spec(_arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :transient}
  end

  @doc false
  def start_link do
    ensure!()
    :ignore
  end

  @doc "Fetches (creating if needed) the bootstrap organization."
  def ensure! do
    first_organization() || create!()
  end

  @doc "Returns the bootstrap organization. Raises if the platform has not booted."
  def organization! do
    first_organization() || raise "bootstrap organization missing — did the app boot?"
  end

  # Single-tenant: THE organization is the first (and normally only) row.
  # Looking it up positionally rather than by name keeps renames safe.
  defp first_organization do
    Repo.one(from o in Organization, order_by: [asc: o.id], limit: 1)
  end

  defp create! do
    %Organization{}
    |> Ecto.Changeset.change(
      name: org_name(),
      email: "ops@localhost",
      confirmed_at: DateTime.utc_now(:second)
    )
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :name)
    |> case do
      %Organization{id: nil} -> first_organization()
      organization -> organization
    end
  end

  defp org_name, do: System.get_env("BOOTSTRAP_ORG_NAME", "local")
end
