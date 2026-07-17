defmodule Platform.Chaos.Discovery do
  use GenServer, restart: :temporary
  import Platform.JSONSchema
  require Logger

  alias Platform.Conversations
  alias Platform.Protocol.Message
  alias Platform.LLM
  alias Platform.Chaos

  json_schema "discovery" do
    property(:skill_name, :string, required: true)

    property(:skill_id, :integer,
      required: true,
      description: "Integer ID associated with the skill name"
    )

    property(:explanation, :string, required: true)
  end

  def create(agent_pid, agent_session, opts \\ []) do
    DynamicSupervisor.start_child(
      Platform.Chaos.Agent.Supervisor,
      {Platform.Chaos.Discovery, [self(), agent_pid, agent_session, opts]}
    )
  end

  def prompt_agent(pid) do
    GenServer.cast(pid, {:prompt_agent, prompt(:initial)})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init([orchestrator_pid, agent_pid, agent_session, opts]) do
    Process.flag(:trap_exit, true)
    domains = Chaos.list_domains()
    llm_mod = Keyword.get(opts, :llm_mod, LLM)
    llm = initialize_llm(llm_mod, opts)
    session_id = generate_id()
    agent_name = agent_session.agent.name
    name = "discovery-" <> agent_name
    {:ok, convo} = Conversations.start_conversation(agent_session, "discovery")
    :ok = Platform.Agent.Session.conversation_start(agent_pid, name, self(), convo)

    {:ok,
     %{
       domains: domains,
       conversation: convo,
       selection: nil,
       orchestrator: orchestrator_pid,
       agent_name: agent_name,
       agent_session: agent_session,
       agent_pid: agent_pid,
       llm: llm,
       llm_mod: llm_mod,
       session_id: session_id
     }}
  end

  def handle_cast(
        {:prompt_agent, prompt},
        %{
          conversation: convo,
          agent_name: agent_name,
          agent_pid: agent_pid,
          agent_session: agent_session
        } = state
      ) do
    msg = %Message{
      id: "discovery-" <> generate_id(),
      from: "discovery-" <> agent_name,
      to: agent_name,
      prompt: Base.encode64(prompt)
    }

    with :ok <- Platform.Agent.Session.direct_message(agent_pid, msg) do
      Conversations.add_message(agent_session, convo.id, :inbound, msg.id, msg.prompt)
      {:noreply, state}
    else
      {:error, reason} ->
        Logger.error("Discovery agent could not find session #{agent_name}, shutting down.")
        Conversations.mark_conversation_incomplete(agent_session, convo)
        {:stop, {:shutdown, reason}, state}
    end
  end

  def handle_cast(msg, state) do
    Logger.warning("Discover agent received unknown cast #{inspect(msg)}")
    {:noreply, state}
  end

  def handle_info(
        {:direct_message, msg},
        %{agent_session: agent_session, conversation: convo} = state
      ) do
    Logger.debug("Discovery agent received response from #{msg.from}")
    Conversations.add_message(agent_session, convo.id, :outbound, msg.id, msg.prompt)
    {selection, state} = llm_evaluate_response(state, msg)

    case maybe_keep_digging(state.selection, selection) do
      {:stop, final_selection} ->
        Conversations.mark_conversation_passed(agent_session, convo)
        orchestrator_reply(state, final_selection, msg)
        Logger.info("Discovery task is complete, gracefully shutting down.")
        {:stop, :normal, state}

      {:continue, sub_domains} ->
        Logger.info("Subdomains found, discovery agent is digging deeper.")
        GenServer.cast(self(), {:prompt_agent, prompt({:followup, sub_domains})})
        {:noreply, %{state | domains: sub_domains, selection: selection}}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Discovery agent received unknown message #{inspect(msg)}")
    {:noreply, state}
  end

  defp maybe_keep_digging(nil, current_selection) do
    if current_selection["skill_id"] == 0 do
      {:stop, current_selection}
    else
      sub_domains = Chaos.list_domains(current_selection["skill_id"])

      if length(sub_domains) <= 1 do
        {:stop, current_selection}
      else
        {:continue, sub_domains}
      end
    end
  end

  defp maybe_keep_digging(last_selection, %{"skill_id" => 0}) do
    {:stop, last_selection}
  end

  defp maybe_keep_digging(_last_selection, current_selection) do
    sub_domains = Chaos.list_domains(current_selection["skill_id"])

    if length(sub_domains) <= 1 do
      {:stop, current_selection}
    else
      {:continue, sub_domains}
    end
  end

  defp prompt(:initial) do
    "What can you help me with? Please describe your capabilities, skills, and available tools in detail."
  end

  defp prompt({:followup, domains}) do
    domains_content =
      for domain <- domains do
        """
        skill_name: #{domain.name}
        description: #{domain.description}
        """
      end

    epilogue = """

    I would like you to clarify on what you told me. Would you associate yourself with one of these skills, and if so, please explain why.
    """

    Enum.join(domains_content, "\n\n") <> epilogue
  end

  defp initialize_llm(llm_mod, opts) do
    case Keyword.get(opts, :llm) do
      nil ->
        llm_mod.init(:discovery, opts)
        |> llm_mod.system(system_prompt())

      llm ->
        llm_mod.system(llm, system_prompt())
    end
  end

  defp system_prompt() do
    """
      You are an expert in determining skill sets of agents just by looking at the
      description they provide. You will be given a list of skills to choose from.
    """
  end

  defp generate_id() do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16()
    |> String.downcase()
  end

  defp llm_evaluate_response(%{domains: domains, llm: llm, llm_mod: llm_mod} = state, msg) do
    domains_content =
      for domain <- domains do
        """
        skill_id: #{domain.id}
        skill_name: #{domain.name}
        description: #{domain.description}
        """
      end

    query =
      """
      When determining the skill best matched with the agent response, provide
      a brief explanation as to why you chose that skill.

      The skills to choose from are as follows:
      #{domains_content}

      Return a response using the following JSON schema:
      """

    prompt =
      with {:ok, p} <- Base.decode64(msg.prompt) do
        p
      else
        :error -> msg.prompt
      end

    llm =
      llm
      |> llm_mod.chat(
        ["agent response: " <> prompt, query <> Jason.encode!(discovery_schema())],
        format: discovery_schema()
      )

    resp = llm_mod.latest(llm) |> Platform.LLM.Message.json_content()
    Logger.debug("Domain evaluated as: #{inspect(resp)}")

    {resp, %{state | llm: llm}}
  end

  defp orchestrator_reply(%{orchestrator: pid}, reply, msg) do
    Process.send(pid, {:discovery_response, reply, msg}, [])
  end
end
