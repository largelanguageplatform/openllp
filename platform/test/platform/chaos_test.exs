defmodule Platform.ChaosTest do
  use Platform.DataCase, async: true
  import Platform.AdminFixtures

  alias Platform.Chaos

  test "list enabled skilled prompts" do
    domain = domain_fixture()
    prompt1 = domain_persona_fixture(domain)
    domain_persona_fixture(domain, %{status: :disabled})

    assert [p] = Chaos.list_prompts(domain)
    assert p.name == prompt1.name
  end

  test "list all prompts and child prompts" do
    grandparent_domain = domain_fixture()
    parent_domain = domain_fixture(%{parent_domain_id: grandparent_domain.id})
    domain = domain_fixture(%{parent_domain_id: parent_domain.id})
    prompt1 = domain_persona_fixture(grandparent_domain)
    prompt2 = domain_persona_fixture(parent_domain)
    prompt3 = domain_persona_fixture(domain)

    assert [p1, p2, p3 | _rest] = Chaos.list_prompts(domain)
    assert p1.name == prompt1.name
    assert p2.name == prompt2.name
    assert p3.name == prompt3.name
  end

  test "list all subdomains" do
    domain = domain_fixture()
    subdomain = domain_fixture(%{parent_domain_id: domain.id})
    [d1, d2] = Chaos.list_domains(domain.id)
    assert d1.id == subdomain.id
    assert d2.id == 0
  end
end
