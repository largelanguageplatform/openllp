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
end
