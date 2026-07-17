defmodule Platform.Chaos.Agent do
  use GenServer, restart: :transient
  require Logger

  alias Platform.Conversations
  alias Platform.Chaos.Story
  alias Platform.Admin.DomainPersona
  alias Platform.Protocol.Message

  def question_schema() do
    %{
      "title" => "Question format",
      "description" => "Used for delivering questions to agents.",
      "type" => "object",
      "properties" => %{
        "question" => %{
          "type" => "string"
        },
        "attachment" => %{
          "type" => "object",
          "description" =>
            "Optionally send an attachment to agents. Do not send an attachment if you have not been provided one earlier.",
          "properties" => %{
            "url" => %{
              "type" => "string",
              "description" => "Attachment URL location"
            },
            "filename" => %{
              "type" => "string",
              "description" => "Attachment filename"
            }
          },
          "required" => ["url", "filename"]
        }
      },
      "required" => ["question"]
    }
  end

  def create(agent_pid, agent_session, %DomainPersona{} = persona, opts \\ []) do
    DynamicSupervisor.start_child(
      Platform.Chaos.Agent.Supervisor,
      {Platform.Chaos.Agent, [agent_pid, agent_session, persona, opts]}
    )
  end

  def converse(pid, description, opts \\ []) do
    GenServer.cast(pid, {:init_conversation, description, opts})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init([agent_pid, agent_session, persona, opts]) do
    Process.flag(:trap_exit, true)
    agent_name = agent_session.agent.name
    session_id = generate_id()
    name = "tester-" <> persona.name <> "--" <> session_id <> "-" <> agent_name
    {:ok, convo} = Conversations.start_conversation(agent_session, persona.name)
    Platform.Agent.Session.conversation_start(agent_pid, name, self(), convo)

    {:ok,
     %{
       agent_session: agent_session,
       agent_name: agent_name,
       agent_pid: agent_pid,
       persona: persona,
       llm_opts: opts,
       story: nil,
       conversation: convo,
       session_id: session_id,
       name: name
     }, {:continue, :build_story}}
  end

  def handle_continue(:build_story, %{name: name, persona: persona, llm_opts: opts} = state) do
    Logger.info("'#{name}' building story...")
    story = Story.start(persona, opts)
    Logger.info("'#{name}' story ready.")
    {:noreply, %{state | story: story}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ignored, state}
  end

  def handle_cast(
        {:init_conversation, _description, _opts},
        %{
          name: name,
          conversation: convo,
          agent_name: agent_name,
          agent_pid: agent_pid,
          agent_session: agent_session,
          story: story
        } = state
      ) do
    Logger.info("Starting '#{name}' agent.")

    {message, story} = Story.progress_plot(story, question_schema())
    question = Map.fetch!(message, "question")
    Logger.debug("'#{name}' generated genesis message: #{question}")

    case deliver_message(name, agent_name, agent_pid, message) do
      %Message{} = msg ->
        Conversations.add_message(
          agent_session,
          convo.id,
          :inbound,
          msg.id,
          msg.prompt,
          msg.filename
        )

        {:noreply, state |> Map.merge(%{story: story})}

      {:error, reason} ->
        Logger.warning("'#{name}' agent could not find session #{agent_name}, shutting down.")
        {:stop, {:shutdown, reason}, state}
    end
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(
        {:direct_message, %Message{} = msg},
        %{
          story: story,
          name: name,
          agent_name: agent_name,
          agent_pid: agent_pid,
          agent_session: agent_session,
          conversation: convo
        } =
          state
      ) do
    Logger.debug("'#{name}' agent received response from #{msg.from}")
    resp = Base.decode64!(msg.prompt)
    Conversations.add_message(agent_session, convo.id, :outbound, msg.id, msg.prompt)

    case handle_direct_message(resp, story, name, agent_name, agent_pid) do
      {:ok, {msg, story}} ->
        Conversations.add_message(
          agent_session,
          convo.id,
          :inbound,
          msg.id,
          msg.prompt,
          msg.filename
        )

        {:noreply, state |> Map.merge(%{story: story})}

      {{:error, reason}, _story} ->
        Logger.warning("'#{name}' agent could not find session #{agent_name}, shutting down.")
        Conversations.mark_conversation_incomplete(agent_session, convo)
        {:stop, {:shutdown, reason}, state}

      :passed ->
        Logger.info("'#{name}' agent story has finished with result: passed")
        Conversations.mark_conversation_passed(agent_session, convo)
        {:stop, {:shutdown, :passed}, state}

      {:fail, reason} ->
        Logger.info("'#{name}' agent story has finished with result: failed (#{reason})")
        Conversations.mark_conversation_failed(agent_session, convo)
        {:stop, {:shutdown, {:fail, reason}}, state}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Agent received unknown message #{inspect(msg)}")
    {:noreply, state}
  end

  defp handle_direct_message(resp, story, name, agent_name, agent_pid) do
    with {:continue, story} <- Story.evaluate_goal(story, resp),
         {:continue, story} <- Story.take_turn(story),
         {reply, story} <- Story.progress_plot(story, question_schema()) do
      {:ok, {deliver_message(name, agent_name, agent_pid, reply), story}}
    end
  end

  defp generate_id() do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16()
    |> String.downcase()
  end

  defp deliver_message(from, to, to_pid, %{"question" => prompt} = latest) do
    attachment = maybe_use_attachment(from, latest)

    msg =
      %Message{
        id: generate_id(),
        from: from,
        to: to,
        prompt: Base.encode64(prompt)
      }
      |> Message.set_attachment(attachment)

    with :ok <- Platform.Agent.Session.direct_message(to_pid, msg) do
      msg
    end
  end

  defp maybe_use_attachment(from, %{"attachment" => %{"url" => url, "filename" => filename}}) do
    Logger.info("'#{from}' is using attachment #{filename}")
    {url, filename}
  end

  defp maybe_use_attachment(_from, _else), do: nil
end
