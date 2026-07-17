defmodule Platform.Account do
  @moduledoc """
  The Account context.

  Single-tenant: the platform operates as one bootstrap organization
  (see `Platform.Bootstrap`); this context manages its identity.
  """

  alias Platform.Account.Organization
  alias Platform.Repo

  @doc "Gets a single organization, raising if not found."
  def get_organization!(id), do: Repo.get!(Organization, id)

  @doc "Returns a changeset for changing the organization name."
  def change_organization_name(organization, attrs \\ %{}, opts \\ []) do
    Organization.name_changeset(organization, attrs, opts)
  end

  @doc "Updates the organization name."
  def update_organization_name(organization, attrs) do
    organization
    |> Organization.update_name_changeset(attrs)
    |> Repo.update()
  end
end
