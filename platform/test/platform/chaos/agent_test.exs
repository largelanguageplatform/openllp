defmodule Platform.Chaos.AgentTest do
  use Platform.DataCase
  import Platform.AccountFixtures
  import Platform.AgentFixtures

  alias Platform.FakeLLM
  alias Platform.Chaos.Agent
  alias Platform.Admin.DomainPersona
  alias Platform.Protocol.Message

  describe "chaos agent" do
    setup do
      agent_session = agent_session_fixture(organization_scope_fixture())

      %{
        agent_session: agent_session,
        prompt: %DomainPersona{name: "foo", prompt_text: "ask about all things foo", max_turns: 1}
      }
    end

    test "communicates to the agent-under-test", %{agent_session: agent_session, prompt: prompt} do
      responses = [
        """
        {
          "question": "why is the sky blue?"
        }
        """,
        """
        {
          "progressed": true,
          "parameters": [
            {
              "name": "questions_answered",
              "action": "add",
              "value": 1
            }
          ]
        }
        """,
        """
        {
          "question": "why is the sky blue?"
        }
        """
      ]

      llm = FakeLLM.init(:story, responses: responses)

      {:ok, pid} = Agent.create(self(), agent_session, prompt, llm: llm, llm_mod: FakeLLM)

      Agent.converse(pid, "agent description")

      assert_receive {:direct_message, %Message{prompt: encoded_prompt}},
                     :timer.seconds(1)

      prompt = Base.decode64!(encoded_prompt)
      assert prompt == "why is the sky blue?"

      GenServer.stop(pid)
      await_agent_finished(pid)
    end

    test "shuts down when no more turns", %{agent_session: agent_session, prompt: prompt} do
      responses = [
        """
        {
          "question": "why is the sky blue?"
        }
        """,
        """
        {
          "progressed": true,
          "parameters": [
            {
              "name": "questions_answered",
              "action": "add",
              "value": 1
            }
          ]
        }
        """,
        """
        {
          "question": "why is the sky blue?"
        }
        """
      ]

      llm = FakeLLM.init(:chaos, responses: responses)

      {:ok, pid} = Agent.create(self(), agent_session, prompt, llm: llm, llm_mod: FakeLLM)

      Agent.converse(pid, "agent description")

      assert_receive {:direct_message, %Message{from: from}},
                     :timer.seconds(1)

      Process.send(pid, {:direct_message, message_fixture(from)}, [])
      await_agent_finished(pid)
    end
  end

  defp await_agent_finished(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000
  end
end
