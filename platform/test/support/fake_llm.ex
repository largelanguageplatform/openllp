defmodule Platform.FakeLLM do
  alias Platform.FakeLLM

  defstruct tag: nil, model: nil, history: [], system: "", tools: [], latest: nil, responses: []

  def init(tag, opts \\ []) when is_atom(tag) do
    responses = Keyword.get(opts, :responses, [])
    %FakeLLM{tag: tag, responses: responses}
  end

  def system(%FakeLLM{} = llm, _msg) do
    llm
  end

  def chat(llm, msgs, opts \\ [])

  def chat(llm, msgs, _opts)
      when is_list(msgs) do
    user_msgs =
      for m <- :lists.reverse(msgs) do
        %{role: "user", content: m}
      end

    history = user_msgs ++ llm.history

    {resp, remaining_responses} = get_resp(llm.tag, llm.responses)

    %FakeLLM{
      llm
      | latest: %Platform.LLM.Message{content: resp},
        responses: remaining_responses,
        tools: [],
        history: history
    }
  end

  def chat(llm, msg, opts) when is_binary(msg), do: chat(llm, [msg], opts)

  def latest(%FakeLLM{latest: latest}), do: latest

  defp get_resp(_tag, [r | rest]), do: {r, rest}

  defp get_resp(_tag, []),
    do:
      raise(
        "Ran out of responses. Ensure you have provided enough responses when initializing the FakeLLM"
      )
end
