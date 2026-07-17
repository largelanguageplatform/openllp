defmodule Platform.AgentTest do
  alias Platform.Account.Scope
  use Platform.DataCase, async: true

  alias Platform.Agent

  describe "agent registration" do
    import Platform.AccountFixtures, only: [organization_fixture: 1, organization_fixture: 0]
    import Platform.AgentFixtures, only: [unique_agent_name: 0, agent_fixture: 1]

    test "creates an agent entry" do
      org = organization_fixture()
      name = unique_agent_name()
      assert {:ok, agent} = Agent.maybe_register_agent(org, name)
      assert agent.name == name
      assert agent.organization_id == org.id
    end

    test "already exists" do
      org = organization_fixture()
      agent = agent_fixture(Scope.for_organization(org))
      assert {:ok, same_agent} = Agent.maybe_register_agent(org, agent.name)
      assert same_agent.name == agent.name
      assert same_agent.description == agent.description
      assert same_agent.status == agent.status
    end

    test "can update description" do
      org = organization_fixture()
      name = unique_agent_name()
      assert {:ok, agent} = Agent.maybe_register_agent(org, name)
      assert agent.description == nil
      Agent.set_description(agent, "this is a description")
      [agent] = Agent.list_agents(Scope.for_organization(org))
      assert agent.description == "this is a description"
    end

    test "api key is valid" do
      org = organization_fixture()
      name = unique_agent_name()

      assert {:ok, %Platform.Agent.Agent{}} =
               Agent.maybe_register_agent(org, name)

      {:ok, api_key} = Agent.generate_api_key(Scope.for_organization(org))
      assert Agent.get_api_key(api_key) != nil
    end

    test "is public if organization is not internal" do
      org = organization_fixture(%{is_internal: false})
      name = unique_agent_name()
      assert {:ok, agent} = Agent.maybe_register_agent(org, name)
      assert agent.status == :public
    end

    test "is private if organization is internal" do
      org = organization_fixture(%{is_internal: true})
      name = unique_agent_name()
      assert {:ok, agent} = Agent.maybe_register_agent(org, name)
      assert agent.status == :private
    end
  end

  describe "bundles" do
    alias Platform.Agent.Bundle

    import Platform.AgentFixtures

    @invalid_attrs %{
      agent: nil,
      registration_id: nil,
      signed_prekey_id: nil,
      signed_prekey_public: nil,
      signed_prekey_signature: nil,
      identity_key_public: nil
    }

    test "get_bundle!/1 returns the bundle with given id" do
      bundle = bundle_fixture()
      assert Agent.get_bundle!(bundle.agent) == bundle
    end

    test "create_bundle/1 with valid data creates a bundle" do
      valid_attrs = %{
        agent: "alice",
        registration_id: 42,
        signed_prekey_id: 42,
        signed_prekey_public: "some signed_prekey_public",
        signed_prekey_signature: "some signed_prekey_signature",
        identity_key_public: "some identity_key_public"
      }

      assert {:ok, %Bundle{} = bundle} = Agent.create_bundle(valid_attrs)
      assert bundle.agent == "alice"
      assert bundle.registration_id == 42
      assert bundle.signed_prekey_id == 42
      assert bundle.signed_prekey_public == "some signed_prekey_public"
      assert bundle.signed_prekey_signature == "some signed_prekey_signature"
      assert bundle.identity_key_public == "some identity_key_public"
    end

    test "create_bundle/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Agent.create_bundle(@invalid_attrs)
    end

    test "create_bundle/1 with existing data updates the bundle" do
      valid_attrs = %{
        agent: "alice",
        registration_id: 42,
        signed_prekey_id: 42,
        signed_prekey_public: "some signed_prekey_public",
        signed_prekey_signature: "some signed_prekey_signature",
        identity_key_public: "some identity_key_public"
      }

      updated_attrs = %{
        agent: "alice",
        registration_id: 1,
        signed_prekey_id: 1,
        signed_prekey_public: "some signed_prekey_public",
        signed_prekey_signature: "some signed_prekey_signature",
        identity_key_public: "some identity_key_public"
      }

      assert {:ok, %Bundle{}} = Agent.create_bundle(valid_attrs)
      assert {:ok, %Bundle{} = bundle} = Agent.create_bundle(updated_attrs)
      assert bundle.agent == "alice"
      assert bundle.registration_id == 1
      assert bundle.signed_prekey_id == 1
      assert bundle.signed_prekey_public == "some signed_prekey_public"
      assert bundle.signed_prekey_signature == "some signed_prekey_signature"
      assert bundle.identity_key_public == "some identity_key_public"
    end

    test "delete_bundle/1 deletes the bundle" do
      bundle = bundle_fixture()
      assert :ok = Agent.delete_bundle(bundle.agent)
      refute Agent.get_bundle!(bundle.agent)
    end

    test "change_bundle/1 returns a bundle changeset" do
      bundle = bundle_fixture()
      assert %Ecto.Changeset{} = Agent.change_bundle(bundle)
    end
  end

  describe "api_keys" do
    alias Platform.Agent.APIKey

    import Platform.AccountFixtures, only: [organization_scope_fixture: 0]
    import Platform.AgentFixtures

    test "list_api_keys/1 returns all scoped api_keys" do
      scope = organization_scope_fixture()
      other_scope = organization_scope_fixture()
      {:ok, api_key} = Agent.generate_api_key(scope)
      {:ok, other_api_key} = Agent.generate_api_key(other_scope)
      api_key = %APIKey{api_key | key: nil}
      other_api_key = %APIKey{other_api_key | key: nil}
      assert Agent.list_api_keys(scope) == [api_key]
      assert Agent.list_api_keys(other_scope) == [other_api_key]
    end

    test "get_api_key!/2 returns the api_key with given id" do
      other_scope = organization_scope_fixture()
      scope = organization_scope_fixture()
      {:ok, api_key} = Agent.generate_api_key(scope)
      api_key = %APIKey{api_key | key: nil}
      assert Agent.get_api_key!(scope, api_key.id) == api_key
      assert_raise Ecto.NoResultsError, fn -> Agent.get_api_key!(other_scope, api_key.id) end
    end

    test "delete_api_key/2 deletes the api_key" do
      scope = organization_scope_fixture()
      {:ok, api_key} = Agent.generate_api_key(scope)
      assert :ok = Agent.delete_api_keys(scope)
      assert_raise Ecto.NoResultsError, fn -> Agent.get_api_key!(scope, api_key.id) end
    end
  end
end
