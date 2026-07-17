defmodule Platform.Chaos.AttachmentTest do
  use Platform.DataCase, async: true
  import Platform.AccountFixtures

  alias Platform.Chaos

  describe "attachment" do
    setup do
      %{organization: organization_scope_fixture()}
    end

    test "can have info be created", %{organization: scope} do
      {:ok, attachment} =
        Chaos.create_attachment(scope, %{
          filename: "foo.txt",
          location: "test/foo.txt",
          bucket: "localdev"
        })

      assert attachment.filename == "foo.txt"
      assert attachment.location == "test/foo.txt"
      assert attachment.bucket == "localdev"
      assert attachment.organization_id == scope.organization.id
    end

    test "fails creation with invalid filename", %{organization: scope} do
      assert {:error, changeset} =
               Chaos.create_attachment(scope, %{
                 filename: "🙁.txt",
                 location: "test/🙁.txt",
                 bucket: "localdev"
               })

      refute changeset.valid?
      assert %{filename: _} = errors_on(changeset)
    end

    test "can have info be fetched", %{organization: scope} do
      {:ok, _} =
        Chaos.create_attachment(scope, %{
          filename: "foo.txt",
          location: "test/foo.txt",
          bucket: "localdev"
        })

      attachment = Chaos.get_attachment("foo.txt")

      assert attachment.filename == "foo.txt"
      assert attachment.location == "test/foo.txt"
      assert attachment.bucket == "localdev"
      assert attachment.organization.id == scope.organization.id
    end

    test "fetches non-existent info" do
      attachment = Chaos.get_attachment("nonexistent.txt")
      assert attachment == nil
    end
  end
end
