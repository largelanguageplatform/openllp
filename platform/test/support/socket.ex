defmodule Platform.SocketHelper do
  use GenServer

  alias Platform.Conversations
  alias Platform.Agent.Session
  alias Platform.Agent.Agent

  def start_link!() do
    {:ok, pid} = GenServer.start(__MODULE__, [])
    pid
  end

  def shutdown(pid) do
    GenServer.stop(pid)
  end

  def send_message(pid, msg) do
    GenServer.call(pid, {:send_message, {:text, msg}})
    pid
  end

  def skip_authenticate(pid) do
    GenServer.call(pid, :authenticate)
    pid
  end

  def session_id(pid) do
    GenServer.call(pid, :session_id)
  end

  def authenticate(pid, key, name) do
    msg =
      """
      {
        "type": "authenticate",
        "id": "auth",
        "name": "#{name}",
        "key": "#{key}"
      }
      """

    {pid, recv} =
      pid
      |> send_message(msg)
      |> recv_message()

    true = recv =~ "authenticated"
    GenServer.call(pid, :set_default_domain)
    pid
  end

  def online(pid) do
    msg =
      """
      {
        "type": "presence",
        "id": "foo",
        "data": {
          "status": "available"
        }
      }
      """

    pid
    |> send_message(msg)
  end

  def prompt(pid, to, text, encrypted \\ false) do
    msg =
      """
      {
        "type": "message",
        "id": "prompt",
        "data": {
          "to": "#{to}",
          "encrypted": #{encrypted},
          "prompt": "#{text}"
        }
      }
      """

    GenServer.call(pid, {:send_message, {:text, msg}})
    pid
  end

  def recv_message(pid) do
    {:ok, msg} = GenServer.call(pid, :recv_message)
    {pid, msg}
  end

  def connected?(pid) do
    {:ok, connected} = GenServer.call(pid, :check_connected)
    connected
  end

  def start_conversation(pid, name) do
    :ok = GenServer.call(pid, {:start_conversation, name, self()})
    pid
  end

  @impl true
  def init(_) do
    {:ok, s} = Session.init(%{})
    {:ok, %{session: s, connected: true, messages: []}}
  end

  @impl true
  def handle_call(:recv_message, _from, state) do
    case pop_message(state) do
      {state, {_, msg}} ->
        {:reply, {:ok, msg}, state}

      {state, nil} ->
        {:reply, {:ok, :empty}, state}
    end
  end

  def handle_call({:start_conversation, name, pid}, _from, %{session: s} = state) do
    {:ok, c} = Conversations.start_conversation(s.session.agent_session, name)
    convos = Map.put(s.session.conversations, name, %{name: name, conversation: c, pid: pid})
    session = Map.put(s.session, :conversations, convos)
    s = Map.put(s, :session, session)
    {:reply, :ok, Map.put(state, :session, s)}
  end

  def handle_call(:session_id, _from, %{session: s} = state) do
    {:reply, s.session.session_id, state}
  end

  def handle_call(:set_default_domain, _from, %{session: s} = state) do
    session =
      s.session
      |> Map.put(:agent, %Agent{s.session.agent | domain_id: 2})

    s = Map.put(s, :session, session)
    {:reply, :ok, Map.put(state, :session, s)}
  end

  def handle_call(:check_connected, _from, %{connected: connected} = state) do
    {:reply, {:ok, connected}, state}
  end

  def handle_call(:authenticate, _from, %{session: s} = state) do
    session = Map.get(s, :session)
    session = %Session{session | status: :authenticated}
    s = Map.put(s, :session, session)
    {:reply, :ok, Map.put(state, :session, s)}
  end

  @impl true
  def handle_call({:send_message, {opcode, msg}}, _from, %{session: s} = state) do
    case Session.handle_in({msg, [opcode: opcode]}, s) do
      {:ok, s2} ->
        {:reply, :ok, state |> Map.put(:session, s2)}

      {:reply, _, response, s2} ->
        state =
          state
          |> append_message(response)
          |> Map.put(:session, s2)

        {:reply, :ok, state}

      {:stop, _reason, s2} ->
        state =
          state
          |> Map.put(:session, s2)
          |> Map.put(:connected, false)

        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info(msg, %{session: s} = state) do
    case Session.handle_info(msg, s) do
      {:push, response, s2} ->
        state =
          state
          |> append_message(response)
          |> Map.put(:session, s2)

        {:noreply, state}

      {:ok, s2} ->
        {:noreply, state |> Map.put(:session, s2)}

      {:stop, _reason, s2} ->
        state =
          state
          |> Map.put(:session, s2)
          |> Map.put(:connected, false)

        {:noreply, state}
    end
  end

  defp append_message(%{messages: m} = state, reply) do
    m = [reply | m]
    Map.put(state, :messages, m)
  end

  defp pop_message(%{messages: []} = state) do
    {state, nil}
  end

  defp pop_message(%{messages: m} = state) do
    [h | rest] = Enum.reverse(m)
    {Map.put(state, :messages, Enum.reverse(rest)), h}
  end
end
