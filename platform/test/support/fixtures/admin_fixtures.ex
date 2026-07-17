defmodule Platform.AdminFixtures do
  alias Platform.Agent.Domain
  alias Platform.Admin.DomainPersona
  alias Platform.Repo

  def unique_domain_name(), do: "domain#{System.unique_integer()}"
  def unique_domain_persona_name(), do: "domainpersona#{System.unique_integer()}"

  def domain_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: unique_domain_name(),
        description: "test description",
        parent_domain_id: 0
      })

    %Domain{}
    |> Domain.changeset(attrs)
    |> Repo.insert!()
  end

  def domain_persona_fixture(%Domain{} = domain, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        domain_id: domain.id,
        name: unique_domain_persona_name(),
        prompt_text: "test prompt",
        status: :enabled
      })

    %DomainPersona{}
    |> DomainPersona.changeset(attrs)
    |> Repo.insert!()
  end
end
