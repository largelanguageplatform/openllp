# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Platform.Repo.insert!(%Platform.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Platform.Conversations.{AgentSession, ConversationMessage, SessionConversation}
alias Platform.Agent.Agent
alias Platform.Agent.APIKey

# The single-tenant bootstrap organization (also created at app boot).
org = Platform.Bootstrap.ensure!()
org2 = org

agent = %Agent{
  organization_id: org.id,
  name: "test-agent",
  description: "This is a test agent, part of the local organization.",
  status: :public
}

agent2 = %Agent{
  organization_id: org.id,
  name: "demo-agent",
  description: "This is the demo agent, used for testing parts of the platform.",
  status: :public
}

session =
  %AgentSession{
    agent: agent2,
    login_at: DateTime.utc_now(:second),
    session: "abc123"
  }
  |> Platform.Repo.insert!()

convo =
  %SessionConversation{
    agent_session: session,
    display_name: "persona 1",
    test_result: :inprogress
  }
  |> Platform.Repo.insert!()

convo2 =
  %SessionConversation{
    agent_session: session,
    display_name: "persona 2",
    test_result: :incomplete
  }
  |> Platform.Repo.insert!()

convo3 =
  %SessionConversation{
    agent_session: session,
    display_name: "persona 3",
    test_result: :fail
  }
  |> Platform.Repo.insert!()

convo4 =
  %SessionConversation{
    agent_session: session,
    display_name: "persona 4",
    test_result: :pass
  }
  |> Platform.Repo.insert!()

%ConversationMessage{
  session_conversation: convo4,
  direction: :inbound,
  message_id: "789",
  prompt: Base.encode64("hello world")
}
|> Platform.Repo.insert!()

%ConversationMessage{
  session_conversation: convo4,
  direction: :annotation,
  message_id: "789",
  annotation_kind: :tool_call,
  annotation_details:
    %{
      "type" => "tool_call",
      "version" => 1,
      "duration_ms" => 500,
      "name" => "get_weather",
      "parameters" => "{\"city\":\"Seattle\"}",
      "threw_exception" => false,
      "result" => "rainy"
    }
    |> Jason.encode!()
}
|> Platform.Repo.insert!()

%ConversationMessage{
  session_conversation: convo4,
  direction: :annotation,
  message_id: "789",
  annotation_kind: :tool_call,
  annotation_details:
    %{
      "type" => "tool_call",
      "version" => 1,
      "duration_ms" => 5000,
      "name" => "get_weather",
      "parameters" => "{\"city\":\"Atlantis\"}",
      "threw_exception" => true,
      "result" => "CityDoesNotExistException"
    }
    |> Jason.encode!()
}
|> Platform.Repo.insert!()

%ConversationMessage{
  session_conversation: convo4,
  direction: :outbound,
  message_id: "789",
  prompt: Base.encode64("hello world"),
  attachment: "attach.txt"
}
|> Platform.Repo.insert!()

decoded = Base.decode64!("testkey", padding: false)

key = %APIKey{
  name: "default",
  enabled: true,
  hashed_key: :crypto.hash(:sha256, decoded) |> Base.encode64(padding: false),
  organization_id: org.id
}

agent = Platform.Repo.insert!(agent)
Platform.Repo.insert!(key)

# Admin users (with temporary passwords - must change on first login)
alias Platform.Admin.User, as: AdminUser
alias Platform.Admin.DomainPersona

admin1 = %AdminUser{
  email: "admin@example.com",
  hashed_password: Argon2.hash_pwd_salt("TempAdmin123!"),
  password_changed_at: nil
}

admin2 = %AdminUser{
  email: "admin2@example.com",
  hashed_password: Argon2.hash_pwd_salt("TempAdmin456!"),
  password_changed_at: nil
}

Platform.Repo.insert!(admin1)
Platform.Repo.insert!(admin2)

# Example domains and chaos-test personas (weather, invoice, tax_noob) are
# provisioned by Platform.Bootstrap at first boot — they are not seeded here
# to keep seeds re-runnable next to a booted app.
