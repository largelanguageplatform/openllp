defmodule Platform.Chaos.OrchestratorTest do
  use Platform.DataCase
  import Platform.AccountFixtures
  import Platform.AgentFixtures

  alias Platform.Chaos.Orchestrator
  alias Platform.FakeLLM

  describe "discovery" do
    setup do
      scope = organization_scope_fixture()
      %{scope: scope, agent_session: agent_session_fixture(scope)}
    end

    test "already completed", %{agent_session: agent_session} do
      assert {:ok, pid} = Orchestrator.start(agent_session)
      Orchestrator.run_tests(pid, llm_mod: Platform.FakeLLM)
      assert :running_tests == Orchestrator.phase(pid)
      Orchestrator.shutdown(pid)
    end

    ## TODO: fix race conditions, perhaps just write a better test..
    @tag :skip
    test "still needed", %{scope: scope} do
      agent_session = agent_session_fixture(scope, %{domain_id: nil})
      Platform.Agent.Manager.join(agent_session.session)

      Platform.Agent.Manager.set_name(
        agent_session.agent.name,
        {agent_session.session, agent_session.agent}
      )

      assert {:ok, pid} = Orchestrator.start(agent_session)
      Orchestrator.subscribe(pid)

      llm = FakeLLM.init(:discovery)
      Orchestrator.run_tests(pid, llm: llm, llm_mod: Platform.FakeLLM)
      assert :discovery == Orchestrator.phase(pid)
      Orchestrator.shutdown(pid)
    end
  end
end
