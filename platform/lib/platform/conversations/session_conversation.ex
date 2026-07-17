defmodule Platform.Conversations.SessionConversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_conversations" do
    field :test_result, Ecto.Enum, values: [inprogress: 0, incomplete: 1, fail: 2, pass: 3]
    field :display_name, :string

    belongs_to :agent_session, Platform.Conversations.AgentSession
    has_many :conversation_messages, Platform.Conversations.ConversationMessage

    timestamps(type: :utc_datetime)
  end

  def changeset(session_conversation, attrs) do
    session_conversation
    |> cast(attrs, [:display_name, :test_result])
    |> validate_required([:display_name, :test_result])
    |> validate_length(:display_name, min: 2, max: 50)
    |> validate_inclusion(:test_result, [:inprogress, :incomplete, :fail, :pass])
  end

  def test_result_changeset(session_conversation, attrs) do
    session_conversation
    |> cast(attrs, [:test_result])
    |> validate_required([:test_result])
    |> validate_inclusion(:test_result, [:inprogress, :incomplete, :fail, :pass])
  end
end
