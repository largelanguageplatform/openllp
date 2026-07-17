defmodule Platform.Agent.Session do
  require Logger

  alias Platform.Protocol.ToolCall
  alias Platform.Conversations
  alias Platform.Chaos.Orchestrator
  alias Platform.Agent
  alias Platform.Agent.APIKey
  alias Platform.Agent.Session
  alias Platform.Protocol.{Error, Auth, Presence, Message}
  alias Platform.Protocol

  defstruct session_id: nil,
            agent: nil,
            agent_session: nil,
            status: :unauthenticated,
            presence: :unavailable,
            supports_encryption?: false,
            api_key: nil,
            message_count: 0,
            name: nil,
            conversations: %{}

  @behaviour Phoenix.Socket.Transport

  def direct_message(pid, msg) do
    receive do
      {:DOWN, _ref, :process, ^pid, reason} ->
        {:error, reason}
    after
      0 ->
        Process.send(pid, {:direct_message, msg}, [])
    end
  end

  def refresh_update(name) do
    with {:ok, pid} <- Platform.Agent.Manager.get_session(name) do
      Process.send(pid, :refresh, [])
    end
  end

  def conversation_start(pid, name, chaos_pid, conversation) do
    ref = Process.monitor(pid)
    Process.send(pid, {:conversation_start, name, chaos_pid, conversation}, [])

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} ->
        {:error, reason}

      {:ok, ^pid} ->
        :ok
    after
      :timer.seconds(5) ->
        {:error, :timed_out}
    end
  end

  def child_spec(_opts) do
    :ignore
  end

  def connect(state) do
    {:ok, state}
  end

  def init(state) do
    session =
      %Session{}
      |> generate_session_id()

    Platform.Agent.Manager.join(session.session_id)
    {:ok, state |> Map.put(:session, session)}
  end

  def handle_in({text, [opcode: opcode]}, %{session: s} = state) do
    {s2, reply} =
      {s, text}
      |> deserialize()
      |> process_inbound()
      |> serialize()

    {:reply, :ok, {opcode, reply}, Map.put(state, :session, s2)}
  end

  def handle_in(_data, state) do
    {:stop, {:shutdown, :unsupported}, state}
  end

  def handle_info(:disconnect, state) do
    {:stop, {:shutdown, :close}, state}
  end

  def handle_info({:conversation_start, name, chaos_pid, conversation}, %{session: s} = state) do
    Logger.info("Received presence from session #{name} with status available")
    Process.monitor(chaos_pid)

    value = %{
      pid: chaos_pid,
      conversation_id: conversation.id,
      name: name
    }

    conversations = Map.put(s.conversations, name, value)

    presence = %Presence{
      id: name <> "-presence",
      from: name,
      status: :available
    }

    direct_message(self(), presence)
    Process.send(chaos_pid, {:ok, self()}, [])
    s2 = Map.put(s, :conversations, conversations)
    {:ok, Map.put(state, :session, s2)}
  end

  def handle_info({:direct_message, msg}, %{session: s} = state) do
    Logger.info("Sending message to remote peer #{s.name}")

    s2 =
      s
      |> increment_message_count()
      |> broadcast_update()

    {:push, {:text, Protocol.serialize(msg)}, Map.put(state, :session, s2)}
  end

  def handle_info(:refresh, %{session: s} = state) do
    s2 =
      s
      |> broadcast_update()

    {:ok, Map.put(state, :session, s2)}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{session: s} = state) do
    {selected, rest} =
      s.conversations
      |> Map.split_with(fn {_k, v} ->
        pid == v.pid
      end)

    case Map.keys(selected) do
      [name] ->
        presence = %Presence{
          id: name <> "-presence",
          from: name,
          status: :unavailable
        }

        Logger.info("Received presence from session #{name} with status unavailable")

        direct_message(self(), presence)
        s2 = Map.put(s, :conversations, rest)
        {:ok, Map.put(state, :session, s2)}

      _no_match ->
        s2 = Map.put(s, :conversations, rest)
        {:ok, Map.put(state, :session, s2)}
    end
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  def terminate(_reason, %{session: s}) do
    s
    |> Map.put(:presence, :unavailable)
    |> broadcast_update()

    Conversations.finish_session(s.agent_session)
    :ok
  end

  defp generate_session_id(session) do
    id =
      :crypto.strong_rand_bytes(4)
      |> Base.encode16()
      |> String.downcase()

    %Session{session | session_id: id}
  end

  defp deserialize({state, text}) do
    case Jason.decode(text) do
      {:ok, term} ->
        Logger.debug("received json message: #{inspect(term)}")
        {state, Protocol.from_map(term)}

      {:error, _reason} ->
        {state, Error.deserialize_error()}
    end
  end

  defp serialize({state, %{type: "ack"} = ack}) do
    {state, ack |> Jason.encode!()}
  end

  defp serialize({state, %Error{} = err}) do
    {state, Error.serialize(err)}
  end

  defp serialize({state, %Auth{} = msg}) do
    {state, Auth.serialize(msg.id, state.session_id)}
  end

  defp process_inbound({%{status: :unauthenticated} = state, msg}),
    do: authenticate(state, msg)

  defp process_inbound({%{status: :authenticated} = state, %Presence{} = p}),
    do: presence(state, p)

  defp process_inbound({%{status: :authenticated} = state, %Message{} = msg}),
    do: message(state, msg)

  defp process_inbound({%{status: :authenticated} = state, %ToolCall{} = tool}),
    do: tool_call(state, tool)

  defp process_inbound({state, msg}), do: {state, msg}

  defp authenticate(state, %Auth{key: key, name: name} = msg) do
    Logger.info("attempting authentication")

    case Platform.Agent.get_api_key(key) do
      nil ->
        Logger.warning("received invalid api key, disconnecting.")
        disconnect()
        {state, Error.invalid_key(msg.id)}

      %APIKey{} = api_key ->
        with {:ok, agent} <- Agent.maybe_register_agent(api_key.organization, name),
             :ok <- Platform.Agent.Manager.set_name(name, {state.session_id, agent}),
             {:ok, agent_session} <- Conversations.create_session(agent, state.session_id) do
          state =
            state
            |> Map.merge(%{
              api_key: api_key,
              status: :authenticated,
              agent: agent,
              agent_session: agent_session,
              name: name
            })

          {state, msg}
        else
          {:error, :name_taken} ->
            Logger.warning("Failed to register agent with error: name taken")
            {state, Error.name_registered(msg.id, name)}

          {:error, e} ->
            Logger.error("Failed to register agent with error: #{inspect(e.errors)}")
            {state, Error.general_error(msg.id)}
        end
    end
  end

  defp authenticate(state, msg) do
    disconnect()

    case msg do
      %Error{} = e -> {state, e}
      _else -> {state, Error.unauthenticated(msg.id)}
    end
  end

  defp presence(state, p) do
    Logger.info("'#{state.name}' setting presence #{p.status}")

    state =
      state
      |> Map.put(:presence, p.status)
      |> Map.put(:supports_encryption?, p.supports_encryption?)
      |> broadcast_update()
      |> start_orchestrator()

    {state, Protocol.ack(p)}
  end

  defp message(%{supports_encryption?: false} = state, %Message{id: id, encrypted?: true}) do
    {state, Error.encryption_unsupported(id)}
  end

  defp message(%{conversations: convos} = state, msg) do
    msg = %Message{msg | from: state.name}
    Logger.info("Sending message from #{state.session_id} to #{msg.to}")

    with %{pid: pid} <- Map.get(convos, msg.to, {:error, :not_found}),
         :ok <- direct_message(pid, msg) do
      {state, Protocol.ack(msg)}
    else
      {:error, reason} ->
        Logger.error("Message send failed with reason: #{inspect(reason)}")
        {state, Error.agent_not_found(msg.id, msg.to)}
    end
  end

  defp tool_call(%{conversations: convos} = state, tool) do
    details = ToolCall.to_annotation_json(tool)
    Logger.debug("Creating tool call annotation: #{inspect(details)}")

    with %{conversation_id: cid} <- Map.get(convos, tool.to, {:error, :not_found}),
         {:ok, _} <-
           Conversations.add_tool_call_annotation(state.agent_session, cid, details, tool.id) do
      {state, Protocol.ack(tool)}
    else
      {:error, :not_found} ->
        {state, Error.agent_not_found(tool.id, tool.to)}

      {:error, %Ecto.Changeset{}} ->
        # TODO: return error message
        {state, Error.general_error(tool.id)}
    end
  end

  defp increment_message_count(%{message_count: count} = state) do
    Map.put(state, :message_count, count + 1)
  end

  defp broadcast_update(%{api_key: nil} = state), do: state

  defp broadcast_update(
         %{
           name: name,
           session_id: session_id,
           api_key: key,
           message_count: count,
           presence: p
         } = state
       ) do
    oid = key.organization_id

    agent = %{
      name: name,
      session_id: session_id,
      message_count: count,
      is_online: p == :available
    }

    oid = :erlang.integer_to_binary(oid)
    channel = "agents:updates:" <> oid

    Logger.debug("broadcasting phoenix update for #{name} to channel #{channel}")
    Phoenix.PubSub.broadcast(Platform.PubSub, channel, {:refresh, agent})
    state
  end

  defp start_orchestrator(%{agent: agent, agent_session: agent_session} = state) do
    if agent.status == :public do
      Logger.info("Starting orchestrator and running tests.")
      {:ok, pid} = Orchestrator.start(agent_session |> Map.merge(%{agent: agent}))
      Orchestrator.run_tests(pid)
      state
    else
      Logger.info("Agent is not public, not starting orchestrator")
      state
    end
  end

  defp disconnect(), do: Process.send(self(), :disconnect, [])
end
