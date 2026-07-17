defmodule Platform.Chaos.Discovery.Test do
  use Platform.DataCase
  import Platform.AccountFixtures
  import Platform.AgentFixtures
  import Platform.AdminFixtures

  alias Platform.FakeLLM
  alias Platform.Chaos.Discovery
  alias Platform.Protocol.Message

  describe "discovery" do
    setup do
      agent_session = agent_session_fixture(organization_scope_fixture())
      %{agent_session: agent_session}
    end

    defp response_builder(domain), do: response_builder([], domain)

    defp response_builder(responses, domain) do
      responses ++
        [
          """
          {
            "skill_id": #{domain.id},
            "skill_name": "#{domain.name}",
            "explanation": ""
          }
          """
        ]
    end

    test "one-shot discovery", %{agent_session: agent_session} do
      responses = response_builder(%{id: 2, name: "finance"})

      llm = FakeLLM.init(:discovery, responses: responses)

      {:ok, pid} = Discovery.create(self(), agent_session, llm: llm, llm_mod: FakeLLM)
      Process.monitor(pid)
      Discovery.prompt_agent(pid)

      assert_receive {:direct_message, %Message{from: from}}, :timer.seconds(1)
      Process.send(pid, {:direct_message, message_fixture(from)}, [])
      assert_receive {:discovery_response, reply, _msg}, :timer.seconds(1)
      assert reply["skill_name"] == "finance"
      assert_receive {:DOWN, _ref, :process, ^pid, _reason}, :timer.seconds(1)
    end

    test "multi-turn discovery", %{agent_session: agent_session} do
      parent_domain = domain_fixture()
      domain = domain_fixture(%{parent_domain_id: parent_domain.id})

      responses =
        parent_domain
        |> response_builder()
        |> response_builder(domain)

      llm = FakeLLM.init(:discovery, responses: responses)
      {:ok, pid} = Discovery.create(self(), agent_session, llm: llm, llm_mod: FakeLLM)
      Process.monitor(pid)
      Discovery.prompt_agent(pid)

      assert_receive {:direct_message, %Message{from: from}}, :timer.seconds(1)
      Process.send(pid, {:direct_message, message_fixture(from)}, [])

      assert_receive {:direct_message, %Message{from: from, prompt: encoded_prompt}},
                     :timer.seconds(1)

      Process.send(pid, {:direct_message, message_fixture(from)}, [])

      prompt = Base.decode64!(encoded_prompt)
      assert prompt =~ domain.name
      assert_receive {:discovery_response, reply, _msg}, :timer.seconds(1)
      assert reply["skill_name"] == domain.name
      assert reply["skill_id"] == domain.id
      assert_receive {:DOWN, _ref, :process, ^pid, _reason}, :timer.seconds(1)
    end

    test "back-track discovery", %{agent_session: agent_session} do
      parent_domain = domain_fixture()
      domain = domain_fixture(%{parent_domain_id: parent_domain.id})

      responses =
        parent_domain
        |> response_builder()
        |> response_builder(%{id: 0, name: "general"})

      llm = FakeLLM.init(:discovery, responses: responses)
      {:ok, pid} = Discovery.create(self(), agent_session, llm: llm, llm_mod: FakeLLM)
      Process.monitor(pid)
      Discovery.prompt_agent(pid)

      assert_receive {:direct_message, %Message{from: from}}, :timer.seconds(1)
      Process.send(pid, {:direct_message, message_fixture(from)}, [])

      assert_receive {:direct_message, %Message{from: from, prompt: encoded_prompt}},
                     :timer.seconds(1)

      Process.send(pid, {:direct_message, message_fixture(from)}, [])

      prompt = Base.decode64!(encoded_prompt)
      assert prompt =~ domain.name
      assert_receive {:discovery_response, reply, _msg}, :timer.seconds(1)
      assert reply["skill_name"] == parent_domain.name
      assert reply["skill_id"] == parent_domain.id
      assert_receive {:DOWN, _ref, :process, ^pid, _reason}, :timer.seconds(1)
    end

    test "nothing discovered, use general", %{agent_session: agent_session} do
      responses = response_builder(%{id: 0, name: "general"})

      llm = FakeLLM.init(:discovery, responses: responses)
      {:ok, pid} = Discovery.create(self(), agent_session, llm: llm, llm_mod: FakeLLM)
      Process.monitor(pid)
      Discovery.prompt_agent(pid)

      assert_receive {:direct_message, %Message{from: from}}, :timer.seconds(1)
      Process.send(pid, {:direct_message, message_fixture(from)}, [])
      assert_receive {:discovery_response, reply, _msg}, :timer.seconds(1)
      assert reply["skill_name"] == "general"
      assert_receive {:DOWN, _ref, :process, ^pid, _reason}, :timer.seconds(1)
    end
  end
end
