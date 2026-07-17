defmodule Platform.ConversationsTest do
  use Platform.DataCase, async: true
  import Platform.AgentFixtures
  import Platform.AccountFixtures
  alias Platform.Conversations

  describe "agent sessions" do
    setup do
      %{
        agent: agent_fixture(organization_scope_fixture()),
        session: "session#{System.unique_integer()}"
      }
    end

    test "can create session and get session", %{agent: agent, session: session} do
      assert {:ok, s} = Conversations.create_session(agent, session)
      actual = Conversations.get_session(agent, session)
      assert s.session == actual.session
      assert s.login_at == actual.login_at
      assert s.agent_id == actual.agent_id
    end

    test "can create session and logout", %{agent: agent, session: session} do
      assert {:ok, s1} = Conversations.create_session(agent, session)
      assert {:ok, s2} = Conversations.finish_session(s1)
      actual = Conversations.get_session(agent, session)
      assert s2.logout_at == actual.logout_at
    end

    test "can get multiple sessions", %{agent: agent, session: session} do
      assert {:ok, s1} = Conversations.create_session(agent, "#{session}1")
      assert {:ok, s2} = Conversations.create_session(agent, "#{session}2")
      assert [a2, a1] = Conversations.get_sessions(agent)
      assert a1.id == s1.id
      assert a2.id == s2.id
    end
  end

  describe "session conversation" do
    setup do
      agent = agent_fixture(organization_scope_fixture())
      session = "session#{System.unique_integer()}"
      {:ok, s} = Conversations.create_session(agent, session)

      %{
        agent_session: s
      }
    end

    test "can start conversation", %{agent_session: session} do
      {:ok, convo} = Conversations.start_conversation(session, "invoice")
      assert convo.display_name == "invoice"
      assert convo.test_result == :inprogress
    end

    test "can finish conversation", %{agent_session: session} do
      {:ok, c1} = Conversations.start_conversation(session, "incomplete")
      {:ok, c2} = Conversations.start_conversation(session, "failed")
      {:ok, c3} = Conversations.start_conversation(session, "passed")
      {:ok, a1} = Conversations.mark_conversation_incomplete(session, c1)
      {:ok, a2} = Conversations.mark_conversation_failed(session, c2)
      {:ok, a3} = Conversations.mark_conversation_passed(session, c3)
      assert a1.test_result == :incomplete
      assert a2.test_result == :fail
      assert a3.test_result == :pass
    end
  end

  describe "conversation message" do
    setup do
      agent = agent_fixture(organization_scope_fixture())
      session = "session#{System.unique_integer()}"
      {:ok, s} = Conversations.create_session(agent, session)
      {:ok, convo} = Conversations.start_conversation(s, "conv#{System.unique_integer()}")

      %{
        agent: agent,
        conversation: convo,
        session: s,
        message_id: "message#{System.unique_integer()}"
      }
    end

    test "can add message", %{session: session, conversation: convo, message_id: message_id} do
      assert {:ok, m1} =
               Conversations.add_message(session, convo.id, :inbound, message_id, "hello world")

      assert {:ok, m2} =
               Conversations.add_message(session, convo.id, :outbound, message_id, "goodbye")

      assert m1.direction == :inbound
      assert m1.prompt == "hello world"
      assert m1.attachment == nil
      assert m2.direction == :outbound
      assert m2.prompt == "goodbye"
      assert m2.attachment == nil
    end

    test "can add message with attachment", %{
      session: session,
      conversation: convo,
      message_id: message_id
    } do
      assert {:ok, m} =
               Conversations.add_message(
                 session,
                 convo.id,
                 :inbound,
                 message_id,
                 "please see attached",
                 "attach.txt"
               )

      assert m.attachment == "attach.txt"
    end

    test "can get all conversations by session" do
      agent = agent_fixture(organization_scope_fixture())
      {:ok, session} = Conversations.create_session(agent, "test_session")
      {:ok, c1} = Conversations.start_conversation(session, "convo1")
      {:ok, c2} = Conversations.start_conversation(session, "convo2")
      assert [actual2, actual1] = Conversations.get_all_conversations_by_agent(agent)
      assert c1.display_name == actual1.display_name
      assert c2.display_name == actual2.display_name
    end

    test "can add tool call annotation", %{session: session, conversation: convo, message_id: mid} do
      tool_call =
        """
        {"type": "tool_call", "version": 1, "duration_ms": 100, "name": "get_weather", "parameters": "", "threw_exception": false}
        """

      assert {:ok, a1} = Conversations.add_tool_call_annotation(session, convo.id, tool_call, mid)
      assert a1.annotation_kind == :tool_call
    end

    test "fails bad tool call annotation", %{
      session: session,
      conversation: convo,
      message_id: mid
    } do
      bad_call1 =
        "{\"type\":\"something_else\",\"version\":1,\"name\":\"get_weather\",\"parameters\":\"\",\"threw_exception\":false}"

      bad_call2 =
        "{\"type\":\"tool_call\",\"version\":0,\"name\":\"get_weather\",\"parameters\":\"\",\"threw_exception\":false}"

      bad_call3 =
        "{\"type\":\"tool_call\",\"version\":1,\"duration_ms\":-1,\"name\":\"get_weather\",\"parameters\":\"\",\"threw_exception\":false}"

      bad_json = "{type: tool_call}"
      assert {:error, _} = Conversations.add_tool_call_annotation(session, convo, bad_call1, mid)
      assert {:error, _} = Conversations.add_tool_call_annotation(session, convo, bad_call2, mid)
      assert {:error, _} = Conversations.add_tool_call_annotation(session, convo, bad_call3, mid)
      assert {:error, _} = Conversations.add_tool_call_annotation(session, convo, bad_json, mid)
    end
  end
end
