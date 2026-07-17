defmodule Platform.Agent.SessionTest do
  use Platform.DataCase
  import Platform.AccountFixtures, only: [organization_scope_fixture: 0]
  import Platform.AgentFixtures, only: [agent_fixture: 1]

  alias Platform.SocketHelper

  describe "session disconnects" do
    setup do
      socket = SocketHelper.start_link!()
      on_exit(fn -> SocketHelper.shutdown(socket) end)
      %{socket: socket}
    end

    test "from json decode failure", %{socket: socket} do
      {socket, msg} =
        socket
        |> SocketHelper.send_message("kaboom")
        |> SocketHelper.recv_message()

      assert msg =~ "Invalid JSON"
      refute SocketHelper.connected?(socket)
    end

    test "from wrong protocol schema", %{socket: socket} do
      {socket, msg} =
        socket
        |> SocketHelper.send_message(~s({"foo":"bar"}))
        |> SocketHelper.recv_message()

      assert msg =~ "Invalid protocol schema"
      refute SocketHelper.connected?(socket)
    end

    test "from being unauthenticated", %{socket: socket} do
      {socket, msg} =
        socket
        |> SocketHelper.send_message("""
        {
          "id": "foo",
          "type": "presence",
          "data": {"status": "available"}
        }
        """)
        |> SocketHelper.recv_message()

      assert msg =~ "Not authenticated"
      refute SocketHelper.connected?(socket)
    end
  end

  describe "session stays connected" do
    setup do
      socket = SocketHelper.start_link!()
      on_exit(fn -> SocketHelper.shutdown(socket) end)
      %{socket: socket}
    end

    test "after wrong presence schema", %{socket: socket} do
      {socket, msg} =
        socket
        |> SocketHelper.skip_authenticate()
        |> SocketHelper.send_message("""
        {
          "type": "presence",
          "id": "foo",
          "status": "available"
        }
        """)
        |> SocketHelper.recv_message()

      assert msg =~ "Invalid presence schema"
      assert SocketHelper.connected?(socket)
    end

    test "after wrong message schema", %{socket: socket} do
      {socket, msg} =
        socket
        |> SocketHelper.skip_authenticate()
        |> SocketHelper.send_message("""
        {
          "type": "message",
          "id": "foo",
          "status": "available"
        }
        """)
        |> SocketHelper.recv_message()

      refute msg == :empty
      assert msg =~ "Invalid message schema"
      assert SocketHelper.connected?(socket)
    end
  end

  describe "session can" do
    setup do
      socket = SocketHelper.start_link!()
      on_exit(fn -> SocketHelper.shutdown(socket) end)
      org = organization_scope_fixture()
      {:ok, api_key} = Platform.Agent.generate_api_key(org)

      %{
        socket: socket,
        api_key: api_key,
        agent: agent_fixture(org)
      }
    end

    test "join session manager on start", %{socket: s} do
      assert {:ok, s} == Platform.Agent.Manager.get_session(SocketHelper.session_id(s))
    end

    test "go through authentication flow", %{socket: socket, api_key: key, agent: agent} do
      socket |> SocketHelper.authenticate(key.key, agent.name)
      assert Platform.Agent.Manager.get_session(agent.name) == {:ok, socket}
    end

    test "send presence and receive ack", %{
      socket: socket,
      api_key: key,
      agent: agent
    } do
      {_socket, ack} =
        socket
        |> SocketHelper.authenticate(key.key, agent.name)
        |> SocketHelper.online()
        |> SocketHelper.recv_message()

      assert ack =~ "ack"
    end

    test "send message and receive ack", %{
      socket: socket,
      api_key: key,
      agent: agent
    } do
      {socket, _ack} =
        socket
        |> SocketHelper.authenticate(key.key, agent.name)
        |> SocketHelper.online()
        |> SocketHelper.recv_message()

      socket =
        socket
        |> SocketHelper.start_conversation("testagent")
        |> SocketHelper.prompt("testagent", "Why is the sky blue?")

      assert_receive {:direct_message, _}, 1_000

      {_socket, ack} = SocketHelper.recv_message(socket)
      assert ack =~ "ack"
    end
  end
end
