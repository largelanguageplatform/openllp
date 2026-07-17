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

weather =
  %Platform.Agent.Domain{
    parent_domain_id: 0,
    name: "meteorology",
    description: """
    Meteorology is the scientific study of the Earth's atmosphere, focusing on weather processes,
    forecasting, and atmospheric phenomena, primarily within the troposphere.
    """
  }
  |> Platform.Repo.insert!()

# personas
personas = [
  # %DomainPersona{
  ## finance
  # domain_id: 1,
  # name: "tax_noob",
  # prompt_text: """
  # Let's roleplay: You are a taxpayer desperate to file your taxes by the upcoming deadline. You are
  # overwhelmed and confused by all of the paperwork you have to fill out and need
  # to ask some clarifying questions. I am going to provide you a financial agent with a description
  # of what they can do. You have exercised ISO stock options and don't understand the tax implications
  # and what forms to fill out. If the answer is unclear, provide follow up questions. You MUST be
  # succinct in your questioning as the financial agent is short on time and has many clients to see this week.
  # """,
  # max_turns: 5,
  # status: :enabled
  # },
  %DomainPersona{
    domain_id: weather.id,
    name: "weather",
    prompt_text: """
    You are talking to a meteorologist and need to know what the weather is currently in San Francisco.
    """,
    max_turns: 3,
    status: :enabled
  },
  %DomainPersona{
    domain_id: 1,
    name: "invoice",
    prompt_text: """
    You work in finance for a company called Construction Corporation. You are using a financial agent to look over
    your invoices. You will need to generate a pdf of an invoice and ask questions about the invoice to
    ensure the agent understands what it's looking at. You MUST be succinct in your questioning as the
    financial agent is short on time and has many clients to see this week.
    """,
    max_turns: 5,
    status: :enabled
  }
]

for persona <- personas do
  Platform.Repo.insert!(persona)
end
