defmodule Platform.AgentFixtures do
  alias Platform.Conversations.AgentSession
  alias Platform.Account.Scope
  alias Platform.Agent.Agent
  alias Platform.Protocol.Message

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Agent` context.
  """

  def unique_agent_name(), do: "agent#{System.unique_integer()}"

  def unique_session_id(), do: "session#{System.unique_integer()}"

  @doc """
  Generate a bundle.
  """
  def bundle_fixture(attrs \\ %{}) do
    {:ok, bundle} =
      attrs
      |> Enum.into(%{
        agent: "alice",
        identity_key_public: "some identity_key_public",
        registration_id: 42,
        signed_prekey_id: 42,
        signed_prekey_public: "some signed_prekey_public",
        signed_prekey_signature: "some signed_prekey_signature"
      })
      |> Platform.Agent.create_bundle()

    bundle
  end

  def agent_session_fixture(scope, attrs \\ %{}) do
    agent = agent_fixture(scope, attrs)

    attrs =
      attrs
      |> Enum.into(%{
        session: unique_session_id(),
        login_at: DateTime.utc_now(),
        agent_id: agent.id
      })

    %AgentSession{}
    |> AgentSession.changeset(attrs)
    |> Platform.Repo.insert!()
    |> Map.merge(%{agent: agent})
  end

  def agent_fixture(%Scope{organization: org}, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: unique_agent_name(),
        description: "This is an agent description",
        status: :private,
        domain_id: 2
      })

    %Agent{organization_id: org.id}
    |> Agent.changeset(attrs)
    |> Platform.Repo.insert!()
  end

  def message_fixture(to) do
    %Message{
      to: to,
      prompt: Base.encode64("hello")
    }
  end
end
