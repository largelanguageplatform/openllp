defmodule Platform.Agent.ManagerTest do
  use ExUnit.Case

  alias Platform.Agent.Manager

  defp fake_session(callback_fun) do
    pid = self()

    Process.spawn(
      fn ->
        callback_fun.()
        Process.send(pid, :ready, [])

        receive do
          _ -> :ok
        after
          :timer.seconds(1) ->
            :ok
        end

        Manager.close_session(self())
      end,
      [:monitor]
    )
  end

  describe "agent session" do
    test "can join and leave" do
      {pid2, ref} =
        fake_session(fn ->
          Manager.join("1")
        end)

      receive do
        :ready ->
          assert {:ok, pid2} == Manager.get_session("1")
      after
        :timer.seconds(1) ->
          flunk("process never ready")
      end

      Process.send(pid2, :die, [])

      receive do
        {:DOWN, ^ref, :process, ^pid2, _reason} ->
          assert {:error, :not_found} == Manager.get_session("1")
      after
        :timer.seconds(1) ->
          flunk("process never died")
      end
    end

    test "can set name" do
      {pid2, ref} =
        fake_session(fn ->
          Manager.join("1")
          assert Manager.set_name("foo", {"id", %{}}) == :ok
        end)

      receive do
        :ready ->
          assert {:ok, pid2} == Manager.get_session("1")
      after
        :timer.seconds(1) ->
          flunk("process never ready")
      end

      Process.send(pid2, :die, [])

      receive do
        {:DOWN, ^ref, :process, ^pid2, _reason} ->
          assert {:error, :not_found} == Manager.get_session("1")
      after
        :timer.seconds(1) ->
          flunk("process never died")
      end

      assert Manager.direct_message("foo", "bar") == {:error, :not_found}
    end

    test "can only set name once" do
      {pid2, ref} =
        fake_session(fn ->
          Manager.join("1")
          assert Manager.set_name("bar", {"id", %{}}) == :ok
          assert Manager.set_name("bar", {"id", %{}}) == {:error, :name_taken}
        end)

      receive do
        :ready ->
          assert {:ok, pid2} == Manager.get_session("1")
      after
        :timer.seconds(1) ->
          flunk("process never ready")
      end

      Process.send(pid2, :die, [])

      receive do
        {:DOWN, ^ref, :process, ^pid2, _reason} ->
          assert {:error, :not_found} == Manager.get_session("1")
      after
        :timer.seconds(1) ->
          flunk("process never died")
      end
    end
  end
end
