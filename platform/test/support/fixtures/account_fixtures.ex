defmodule Platform.AccountFixtures do
  @moduledoc """
  Test helpers for creating organizations and scopes.

  Web (conn/LiveView) tests should use `bootstrap_scope_fixture/0` — the
  browser pipeline always scopes requests to the bootstrap organization.
  Context-level tests may create additional organizations freely.
  """

  alias Platform.Account.Organization
  alias Platform.Account.Scope
  alias Platform.Agent

  def unique_organization_email, do: "organization#{System.unique_integer()}@example.com"
  def unique_organization_name, do: "organization#{System.unique_integer()}"

  def valid_organization_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_organization_email(),
      name: unique_organization_name()
    })
  end

  def organization_fixture(attrs \\ %{}) do
    attrs = valid_organization_attributes(attrs)

    %Organization{}
    |> Organization.email_changeset(attrs)
    |> Organization.name_changeset(attrs)
    |> Ecto.Changeset.cast(attrs, [:is_internal])
    |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
    |> Platform.Repo.insert!()
  end

  def organization_scope_fixture do
    organization = organization_fixture()
    organization_scope_fixture(organization)
  end

  def organization_scope_fixture(organization) do
    Scope.for_organization(organization)
  end

  @doc "The scope every browser request runs under (see Platform.Bootstrap)."
  def bootstrap_scope_fixture do
    Scope.for_organization(Platform.Bootstrap.ensure!())
  end

  def set_api_key(organization) do
    scope = organization_scope_fixture(organization)
    Agent.generate_api_key(scope)
  end
end
