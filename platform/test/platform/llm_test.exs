defmodule Platform.LLMTest do
  use ExUnit.Case, async: true

  defp stub_llm_response(content) do
    Req.Test.stub(LLM.Test, fn conn ->
      Process.send(self(), {:request, Map.get(conn.body_params, "messages")}, [])

      response = %{
        "model" => "llama2",
        "created_at" => "2023-12-12T14:13:43.416799Z",
        "message" => %{
          "role" => "assistant",
          "content" => content
        },
        "done" => true,
        "total_duration" => 5_191_566_416,
        "load_duration" => 2_154_458,
        "prompt_eval_count" => 26,
        "prompt_eval_duration" => 383_809_000,
        "eval_count" => 298,
        "eval_duration" => 4_799_921_000
      }

      Req.Test.json(conn, response)
    end)
  end

  defp stub_retry_response(content) do
    Req.Test.expect(LLM.Test, &Req.Test.transport_error(&1, :closed))
    Req.Test.expect(LLM.Test, &Plug.Conn.send_resp(&1, 500, "internal server error"))

    Req.Test.expect(
      LLM.Test,
      &Req.Test.json(&1, %{
        "model" => "llama2",
        "created_at" => "2023-12-12T14:13:43.416799Z",
        "message" => %{
          "role" => "assistant",
          "content" => content
        },
        "done" => true,
        "total_duration" => 5_191_566_416,
        "load_duration" => 2_154_458,
        "prompt_eval_count" => 26,
        "prompt_eval_duration" => 383_809_000,
        "eval_count" => 298,
        "eval_duration" => 4_799_921_000
      })
    )
  end

  test "set system prompt" do
    llm = Platform.LLM.init(:test) |> Platform.LLM.system("hello world")
    assert llm.system == "hello world"
  end

  test "send prompt with system and user message" do
    stub_llm_response("hello world")

    Platform.LLM.init(:test)
    |> Platform.LLM.system("hello world")
    |> Platform.LLM.chat("foo")

    assert_receive {:request,
                    [
                      %{"role" => "system", "content" => "hello world"},
                      %{"role" => "user", "content" => "foo"}
                    ]},
                   1_000
  end

  test "preserve chat history" do
    stub_llm_response("hello")

    Platform.LLM.init(:test)
    |> Platform.LLM.system("hello world")
    |> Platform.LLM.chat("foo")
    |> Platform.LLM.chat("bar")

    # throw out the first request
    assert_receive {:request, _}

    assert_receive {:request,
                    [
                      %{"role" => "system", "content" => "hello world"},
                      %{"role" => "user", "content" => "foo"},
                      %{"role" => "assistant", "content" => "hello"},
                      %{"role" => "user", "content" => "bar"}
                    ]}
  end

  test "send array of messages" do
    stub_llm_response("hello")

    Platform.LLM.init(:test)
    |> Platform.LLM.system("hello world")
    |> Platform.LLM.chat(["foo", "bar"])

    assert_receive {:request,
                    [
                      %{"role" => "system", "content" => "hello world"},
                      %{"role" => "user", "content" => "foo"},
                      %{"role" => "user", "content" => "bar"}
                    ]}
  end

  test "override configured model" do
    llm = Platform.LLM.init(:test, model: "my-model")
    assert llm.model == "my-model"
  end

  test "override ollama options" do
    llm = Platform.LLM.init(:test, receive_timeout: 10_000)
    assert llm.ollama.req.options.receive_timeout == 10_000
  end

  test "get latest message" do
    stub_llm_response("hello")

    msg =
      Platform.LLM.init(:test)
      |> Platform.LLM.chat("foo")
      |> Platform.LLM.latest()

    assert msg.content == "hello"
  end

  test "get latest message as json" do
    stub_llm_response("{\"foo\":\"bar\"}")

    msg =
      Platform.LLM.init(:test)
      |> Platform.LLM.chat("foo")
      |> Platform.LLM.latest()
      |> Platform.LLM.Message.json_content()

    assert msg == %{"foo" => "bar"}
  end

  test "retry request if connection closed or timed out" do
    stub_retry_response("hello")

    msg =
      Platform.LLM.init(:test)
      |> Platform.LLM.chat("foo")
      |> Platform.LLM.latest()

    assert msg.content == "hello"
  end

  test "out of retries" do
    Req.Test.stub(LLM.Test, &Req.Test.transport_error(&1, :closed))

    assert_raise MatchError, fn ->
      Platform.LLM.init(:test)
      |> Platform.LLM.chat("foo")
    end
  end
end
