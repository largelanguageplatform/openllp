defmodule PlatformWeb.Portal.AgentLogsLiveTest do
  use PlatformWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Platform.AccountFixtures
  import Platform.AgentFixtures
  import Platform.ConversationFixtures

  describe "agent logs page" do
    setup do
      scope = bootstrap_scope_fixture()

      %{
        scope: scope,
        agent_session: agent_session_fixture(scope, %{name: "my_agent"})
      }
    end

    test "can load more than one message", %{
      conn: conn,
      agent_session: agent_session,
      scope: scope
    } do
      conversation = conversation_fixture(agent_session)
      message_fixture(conversation, %{prompt: Base.encode64("message 1")})
      message_fixture(conversation, %{prompt: Base.encode64("message 2")})

      {:ok, _lv, html} =
        conn
        |> live(~p"/portal/agents/my_agent/logs")

      assert html =~ "message 1"
      assert html =~ "message 2"
    end

    test "can message with attachment", %{conn: conn, scope: scope, agent_session: agent_session} do
      conversation = conversation_fixture(agent_session)
      message_fixture(conversation, %{attachment: "attachment.txt"})

      {:ok, _lv, html} =
        conn
        |> live(~p"/portal/agents/my_agent/logs")

      assert html =~ "attachment.txt"
    end

    test "can render tool call annotation", %{
      conn: conn,
      scope: scope,
      agent_session: agent_session
    } do
      conversation = conversation_fixture(agent_session)
      annotation_fixture(conversation)

      {:ok, _lv, html} =
        conn
        |> live(~p"/portal/agents/my_agent/logs")

      assert html =~ "my_tool_call"
      assert html =~ "Returned"
    end

    test "can render tool call exception annotation", %{
      conn: conn,
      scope: scope,
      agent_session: agent_session
    } do
      conversation = conversation_fixture(agent_session)

      details =
        annotation_details()
        |> Map.merge(%{
          "threw_exception" => true,
          "result" => "NullReferenceException"
        })
        |> Jason.encode!()

      annotation_fixture(conversation, %{annotation_details: details})

      {:ok, _lv, html} =
        conn
        |> live(~p"/portal/agents/my_agent/logs")

      assert html =~ "my_tool_call"
      assert html =~ "Exception"
      assert html =~ "NullReferenceException"
    end

    test "renders empty page if there are no logs", %{
      conn: conn,
      scope: scope,
      agent_session: agent_session
    } do
      conversation_fixture(agent_session)

      {:ok, _lv, html} =
        conn
        |> live(~p"/portal/agents/my_agent/logs")

      assert html =~ "No messages yet"
    end
  end
end
