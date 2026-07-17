defmodule Platform.AdminTest do
  alias Platform.Admin
  alias Platform.Agent.Domain
  use Platform.DataCase, async: true
  alias Platform.Repo

  test "create domain" do
    general = Repo.get_by!(Domain, id: 0)

    assert {:ok, domain1} =
             Admin.create_domain(general, %{name: "domain1", description: "test domain1"})

    assert {:ok, domain2} =
             Admin.create_domain(domain1, %{name: "domain2", description: "test domain2"})

    assert domain1.name == "domain1"
    assert domain2.name == "domain2"
    assert domain2.parent_domain_id == domain1.id
    assert domain1.parent_domain_id == general.id
  end

  test "list domains in ascending order of domain id" do
    general = Repo.get_by!(Domain, id: 0)
    Admin.create_domain(general, %{name: "domain1", description: "test domain1"})
    Admin.create_domain(general, %{name: "domain2", description: "test domain2"})
    [s1, s2, s3 | _rest] = Admin.list_domains()
    assert s1.id == general.id
    assert s2.id > s1.id
    assert s3.id > s2.id
  end
end
