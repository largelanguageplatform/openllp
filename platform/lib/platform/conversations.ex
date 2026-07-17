defmodule Platform.Conversations do
  alias Platform.Conversations.{
    AgentSession,
    ConversationMessage,
    SessionConversation
  }

  alias Platform.Agent.Agent
  alias Platform.Repo
  import Ecto.Query

  def get_sessions(%Agent{} = agent) do
    from(a in AgentSession,
      where: a.agent_id == ^agent.id,
      order_by: [desc: a.id],
      preload: :session_conversations
    )
    |> Repo.all()
  end

  def get_session(%Agent{} = agent, session) do
    AgentSession
    |> Repo.one(agent_id: agent.id, session: session)
    |> Repo.preload([:session_conversations])
  end

  def create_session(%Agent{} = agent, session) do
    attrs = %{
      agent_id: agent.id,
      session: session,
      login_at: DateTime.utc_now()
    }

    %AgentSession{}
    |> AgentSession.changeset(attrs)
    |> Repo.insert()
  end

  def finish_session(nil) do
    :ok
  end

  def finish_session(%AgentSession{} = session) do
    attrs = %{
      logout_at: DateTime.utc_now()
    }

    session
    |> AgentSession.logout_changeset(attrs)
    |> Repo.update()
  end

  def start_conversation(%AgentSession{} = session, name) do
    attrs = %{
      display_name: name,
      test_result: :inprogress
    }

    result =
      %SessionConversation{agent_session: session}
      |> SessionConversation.changeset(attrs)
      |> Repo.insert()

    with {:ok, r} <- result,
         :ok <-
           Phoenix.PubSub.broadcast(
             Platform.PubSub,
             "agents:#{session.agent_id}",
             {:conversation_update, r}
           ) do
      {:ok, r}
    end
  end

  def mark_conversation_failed(%AgentSession{} = session, %SessionConversation{} = convo),
    do: mark_conversation(session.agent_id, convo, :fail)

  def mark_conversation_passed(%AgentSession{} = session, %SessionConversation{} = convo),
    do: mark_conversation(session.agent_id, convo, :pass)

  def mark_conversation_incomplete(%AgentSession{} = session, %SessionConversation{} = convo),
    do: mark_conversation(session.agent_id, convo, :incomplete)

  def add_message(
        %AgentSession{} = session,
        convo_id,
        direction,
        message_id,
        prompt,
        attachment \\ nil
      ) do
    attrs = %{
      session_conversation_id: convo_id,
      direction: direction,
      message_id: message_id,
      prompt: prompt,
      attachment: attachment
    }

    result =
      %ConversationMessage{}
      |> ConversationMessage.message_changeset(attrs)
      |> Repo.insert()

    with {:ok, r} <- result,
         :ok <-
           Phoenix.PubSub.broadcast(
             Platform.PubSub,
             "agents:#{session.agent_id}:msgs:#{convo_id}",
             {:add_message, r}
           ) do
      {:ok, r}
    end
  end

  def add_tool_call_annotation(
        %AgentSession{} = session,
        convo_id,
        tool_details,
        message_id
      ) do
    attrs = %{
      session_conversation_id: convo_id,
      direction: :annotation,
      message_id: message_id,
      annotation_kind: :tool_call,
      annotation_details: tool_details
    }

    result =
      %ConversationMessage{}
      |> ConversationMessage.annotation_changeset(attrs, :tool_call)
      |> Repo.insert()

    with {:ok, r} <- result,
         :ok <-
           Phoenix.PubSub.broadcast(
             Platform.PubSub,
             "agent:#{session.agent_id}:msgs:#{convo_id}",
             {:add_message, r}
           ) do
      {:ok, r}
    end
  end

  def get_conversation_by_id(id) do
    from(s in SessionConversation,
      where: s.id == ^id,
      preload: :agent_session
    )
    |> Repo.one()
  end

  def get_all_conversations_by_agent(%Agent{} = agent) do
    from(s in SessionConversation,
      join: a in assoc(s, :agent_session),
      where: a.agent_id == ^agent.id,
      order_by: [desc: s.id],
      select: %{
        id: s.id,
        test_result: s.test_result,
        display_name: s.display_name,
        inserted_at: s.inserted_at,
        session: a.session
      }
    )
    |> Repo.all()
  end

  def get_conversation_count_by_agent(%Agent{} = agent) do
    from(s in SessionConversation,
      join: a in assoc(s, :agent_session),
      where: a.agent_id == ^agent.id,
      select: count(s.id)
    )
    |> Repo.one()
  end

  def get_conversation_messages_by_conversation_id(nil), do: []

  def get_conversation_messages_by_conversation_id(id) do
    from(m in ConversationMessage,
      where: m.session_conversation_id == ^id,
      order_by: [asc: m.id],
      preload: :session_conversation
    )
    |> Repo.all()
  end

  defp mark_conversation(agent_id, %SessionConversation{} = convo, result) do
    attrs = %{
      test_result: result
    }

    result =
      convo
      |> SessionConversation.test_result_changeset(attrs)
      |> Repo.update()

    with {:ok, r} <- result,
         :ok <-
           Phoenix.PubSub.broadcast(
             Platform.PubSub,
             "agents:#{agent_id}",
             {:conversation_update, r}
           ) do
      {:ok, r}
    end
  end
end
