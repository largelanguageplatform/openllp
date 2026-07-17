defmodule Platform.Chaos.Orchestrator do
  use GenServer, restart: :transient
  require Logger

  alias Platform.Agent
  alias Platform.Agent.Domain
  alias Platform.Chaos
  alias Platform.Chaos.Agent, as: ChaosAgent
  alias Platform.Chaos.Discovery
  alias Platform.Protocol.Message

  def start(agent_session) do
    helpers = %{
      discovery: Discovery,
      chaos: ChaosAgent
    }

    start(agent_session, helpers)
  end

  def start(agent_session, helpers) do
    DynamicSupervisor.start_child(
      Platform.Chaos.Orchestrator.Supervisor,
      {Platform.Chaos.Orchestrator, [self(), agent_session, helpers]}
    )
  end

  def shutdown(pid) do
    GenServer.stop(pid, :normal)
  end

  def subscribe(pid) do
    GenServer.call(pid, {:subscribe, self()})
  end

  def run_tests(pid, opts \\ []) do
    GenServer.cast(pid, {:run_tests, opts})
  end

  def phase(pid) do
    GenServer.call(pid, :get_phase)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init([pid, agent_session, helpers]) do
    Process.flag(:trap_exit, true)
    ref = Process.monitor(pid)

    {:ok,
     %{
       agent_session: agent_session,
       agent_pid: pid,
       monitor: ref,
       phase: :discovery,
       helpers: helpers
     }}
  end

  def handle_call(:get_phase, _from, %{phase: p} = state), do: {:reply, p, state}

  def handle_call({:subscribe, pid}, _from, state),
    do: {:reply, :ok, Map.put(state, :subscriber, pid)}

  def handle_call(_msg, _from, state), do: {:reply, :ignored, state}

  def handle_cast(
        {:run_tests, opts},
        %{agent_pid: agent_pid, agent_session: agent_session} = state
      ) do
    agent = agent_session.agent

    case Agent.get_domain(agent) do
      nil ->
        Logger.warning(
          "Agent '#{agent.name}' has no set domain, awaiting answer from discovery agent before proceeding."
        )

        {:ok, pid} = Discovery.create(agent_pid, agent_session, opts)
        Discovery.prompt_agent(pid)
        {:noreply, Map.merge(state, %{llm_opts: opts}), :timer.minutes(5)}

      %Domain{} = d ->
        Logger.debug("Agent '#{agent.name}' has domain '#{d.name}', proceeding to testing phase.")
        Process.send(self(), {:start_test, d, agent.description}, [])
        broadcast(state, %{phase_change: %{from: state.phase, to: :testing}})
        {:noreply, Map.merge(state, %{domain: d, phase: :testing, llm_opts: opts})}
    end
  end

  def handle_cast(_msg, state), do: {:noreply, state}

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{agent_session: agent_session, monitor: ref} = state
      ) do
    Logger.warning(
      "'#{agent_session.agent.name}' went down with reason #{inspect(reason)}, shutting down."
    )

    {:stop, :normal, state}
  end

  def handle_info(
        {:discovery_response, %{"skill_name" => domain, "skill_id" => id}, %Message{} = msg},
        %{agent_session: agent_session} = state
      ) do
    agent = agent_session.agent
    Logger.info("Setting '#{agent.name}' domain to #{domain}")
    d = Agent.get_domain_by_id!(id)
    {:ok, _a} = Agent.set_domain(agent, d)
    desc = Base.decode64!(msg.prompt)
    Agent.set_description(agent, desc)
    Process.send(self(), {:start_test, d, desc}, [])
    broadcast(state, %{phase_change: %{from: state.phase, to: :testing}})
    {:noreply, Map.merge(state, %{domain: d, phase: :testing})}
  end

  def handle_info(
        {:start_test, domain, description},
        %{phase: :testing, agent_pid: agent_pid, agent_session: agent_session, llm_opts: opts} =
          state
      ) do
    prompts = Chaos.list_prompts(domain)

    Logger.info(
      "Creating #{length(prompts)} agents for '#{agent_session.agent.name}' based on the '#{domain.name}' domain."
    )

    for prompt <- prompts do
      {:ok, pid} = ChaosAgent.create(agent_pid, agent_session, prompt, opts)
      :ok = ChaosAgent.converse(pid, description)
    end

    {:noreply, Map.put(state, :phase, :running_tests), :timer.minutes(5)}
  end

  def handle_info(:timeout, %{agent_session: agent_session} = state) do
    Logger.info("#{agent_session.agent.name} orchestrator is shutting down due to inactivity")
    {:stop, {:shutdown, :timeout}, state}
  end

  def handle_info(msg, state) do
    Logger.warning("Orchestrator received unknown info message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp broadcast(%{subscriber: pid}, msg) when is_pid(pid) do
    Process.send(pid, {:orchestrator_publish, msg}, [])
  end

  defp broadcast(_none, _msg), do: :ignore
end
