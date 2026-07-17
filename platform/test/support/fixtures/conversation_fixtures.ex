defmodule Platform.ConversationFixtures do
  alias Platform.Conversations.{AgentSession, ConversationMessage, SessionConversation}

  def unique_message_id(), do: "message#{System.unique_integer()}"

  def annotation_details(),
    do: %{
      "type" => "tool_call",
      "version" => 1,
      "duration_ms" => 5000,
      "name" => "my_tool_call",
      "parameters" => "",
      "result" => "",
      "threw_exception" => false
    }

  def conversation_fixture(%AgentSession{} = session, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        display_name: "test",
        test_result: :inprogress
      })

    %SessionConversation{agent_session: session}
    |> SessionConversation.changeset(attrs)
    |> Platform.Repo.insert!()
  end

  def message_fixture(%SessionConversation{} = convo, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        direction: :inbound,
        message_id: unique_message_id(),
        prompt: Base.encode64("test prompt"),
        attachment: nil
      })

    %ConversationMessage{session_conversation_id: convo.id}
    |> ConversationMessage.message_changeset(attrs)
    |> Platform.Repo.insert!()
  end

  def annotation_fixture(%SessionConversation{} = convo, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        direction: :annotation,
        message_id: unique_message_id(),
        annotation_kind: :tool_call,
        annotation_details:
          %{
            "type" => "tool_call",
            "version" => 1,
            "duration_ms" => 5000,
            "name" => "my_tool_call",
            "parameters" => "",
            "threw_exception" => false,
            "result" => ""
          }
          |> Jason.encode!()
      })

    %ConversationMessage{session_conversation_id: convo.id}
    |> ConversationMessage.annotation_changeset(attrs, attrs.annotation_kind)
    |> Platform.Repo.insert!()
  end
end
