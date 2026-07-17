defmodule Platform.Agent.Manager do
  use GenServer
  require Logger
  @moduledoc false

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def join(id) do
    GenServer.call(__MODULE__, {:join, self(), id})
  end

  def close_session(id) do
    GenServer.call(__MODULE__, {:close_session, id})
  end

  def get_agent(name) do
    case :ets.lookup(:session_names, name) do
      [] ->
        {:error, :not_found}

      [{^name, {_id, agent}}] ->
        {:ok, agent}
    end
  end

  def get_session(id_or_name) do
    case {:ets.lookup(:sessions, id_or_name), :ets.lookup(:session_names, id_or_name)} do
      {[], [{^id_or_name, {id, _agent}}]} ->
        get_session(id)

      {[{^id_or_name, pid}], _} ->
        {:ok, pid}

      {[], []} ->
        {:error, :not_found}
    end
  end

  def set_name(name, agent) do
    GenServer.call(__MODULE__, {:name_to_session, name, agent})
  end

  def direct_message(to, msg) do
    case get_session(to) do
      {:ok, pid} ->
        Platform.Agent.Session.direct_message(pid, msg)

      error ->
        error
    end
  end

  def session_count() do
    :ets.info(:sessions, :size)
  end

  def init(_args) do
    Process.flag(:trap_exit, true)
    :ets.new(:sessions, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(:session_names, [:named_table, :protected, :set, read_concurrency: true])
    {:ok, %{next_id: 1}}
  end

  def handle_call({:join, pid, id}, _from, state) do
    :erlang.link(pid)
    :ets.insert(:sessions, {id, pid})
    {:reply, :ok, state}
  end

  def handle_call({:name_to_session, name, agent}, _from, state) do
    case :ets.lookup(:session_names, name) do
      [] ->
        :ets.insert(:session_names, {name, agent})
        {:reply, :ok, state}

      _else ->
        {:reply, {:error, :name_taken}, state}
    end
  end

  def handle_call({:close_session, id}, _from, state) do
    cleanup_session(id)
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, pid, _reason}, state) do
    cleanup_session(pid)
    {:noreply, state}
  end

  defp cleanup_session(pid) when is_pid(pid) do
    case :ets.match(:sessions, {:"$1", pid}) do
      [[session_id]] -> cleanup_session(session_id)
      [] -> :ok
    end
  end

  defp cleanup_session(id) do
    case :ets.match(:session_names, {:"$1", {id, :_}}) do
      [[name]] -> :ets.delete(:session_names, name)
      [] -> :ok
    end

    :ets.delete(:sessions, id)
  end
end
