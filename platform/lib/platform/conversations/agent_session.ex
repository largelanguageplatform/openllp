defmodule Platform.Conversations.AgentSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agent_sessions" do
    field :session, :string
    field :login_at, :utc_datetime
    field :logout_at, :utc_datetime

    belongs_to :agent, Platform.Agent.Agent
    has_many :session_conversations, Platform.Conversations.SessionConversation

    timestamps(type: :utc_datetime)
  end

  def changeset(agent_session, attrs) do
    agent_session
    |> cast(attrs, [:agent_id, :session, :login_at])
    |> validate_required([:agent_id, :session, :login_at])
  end

  def logout_changeset(agent_session, attrs) do
    agent_session
    |> cast(attrs, [:logout_at])
    |> validate_required([:logout_at])
  end
end
