defmodule Platform.BootstrapTest do
  use Platform.DataCase, async: false

  alias Platform.Bootstrap

  test "ensure! is idempotent and returns the same organization" do
    org1 = Bootstrap.ensure!()
    org2 = Bootstrap.ensure!()

    assert org1.id == org2.id
    assert org1.name == "local"
    assert org1.confirmed_at
  end

  test "organization! returns the bootstrap organization" do
    org = Bootstrap.ensure!()
    assert Bootstrap.organization!().id == org.id
  end

  test "example chaos personas are provisioned when the table is empty" do
    Bootstrap.ensure!()

    names = Repo.all(Platform.Admin.DomainPersona) |> Enum.map(& &1.name) |> Enum.sort()
    assert "invoice" in names
    assert "tax_noob" in names
    assert "weather" in names
    assert Repo.get_by(Platform.Agent.Domain, name: "meteorology")
  end

  test "an admin account is provisioned when none exists" do
    Bootstrap.ensure!()

    assert [admin] = Repo.all(Platform.Admin.User)
    assert admin.email == "admin@example.com"
    assert Platform.Admin.User.must_change_password?(admin)
  end

  test "provisioning does not duplicate on repeated boots" do
    Bootstrap.ensure!()
    before = Repo.aggregate(Platform.Admin.DomainPersona, :count)
    admins_before = Repo.aggregate(Platform.Admin.User, :count)
    Bootstrap.ensure!()
    assert Repo.aggregate(Platform.Admin.DomainPersona, :count) == before
    assert Repo.aggregate(Platform.Admin.User, :count) == admins_before
  end
end
