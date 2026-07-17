defmodule Platform.LLM do
  alias Platform.LLM

  @localhost "http://localhost:11434/api"
  @retries 3

  defstruct tag: nil, model: nil, history: [], ollama: nil, system: "", tools: [], latest: nil

  def init(tag, opts \\ []) when is_atom(tag) do
    {model, config} = get_config(opts)

    options =
      config
      |> Keyword.merge(opts)
      |> Keyword.drop([:model])

    client = Ollama.init(options)
    %LLM{tag: tag, ollama: client, model: model}
  end

  def system(%LLM{} = llm, msg) do
    %LLM{llm | system: msg}
  end

  def chat(llm, msgs, opts \\ [])

  def chat(%LLM{ollama: client, model: model, tools: t} = llm, msgs, opts)
      when is_list(msgs) do
    user_msgs =
      for m <- :lists.reverse(msgs) do
        %{role: "user", content: m}
      end

    history = user_msgs ++ llm.history
    h = prepare_history(llm, history)

    chat_opts =
      opts
      |> Keyword.take([:format])
      |> Keyword.merge(model: model, messages: h, tools: t)

    {:ok, reply} = chat_with_retry(client, chat_opts, @retries)

    %LLM{
      llm
      | latest: Platform.LLM.Message.decode(reply),
        tools: [],
        history: [format(reply["message"]) | history]
    }
  end

  def chat(llm, msg, opts) when is_binary(msg), do: chat(llm, [msg], opts)

  def latest(%LLM{latest: latest}), do: latest

  def dump(llm = %LLM{history: history}), do: prepare_history(llm, history)

  defp chat_with_retry(client, chat_opts, retries) do
    case Ollama.chat(client, chat_opts) do
      {:ok, %{} = reply} ->
        {:ok, reply}

      {:error, reason} when retries == 0 ->
        {:error, reason}

      {:error, %Ollama.HTTPError{status: status}} when status >= 500 ->
        chat_with_retry(client, chat_opts, retries - 1)

      {:error, %Ollama.HTTPError{status: status} = resp} when status >= 400 and status <= 499 ->
        {:error, resp}

      {:error, %Req.TransportError{reason: :closed}} ->
        chat_with_retry(client, chat_opts, retries - 1)

      {:error, %Req.TransportError{reason: :timeout}} ->
        chat_with_retry(client, chat_opts, retries - 1)

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, reason}
    end
  end

  defp format(reply) do
    reply
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.take([:role, :content, :images, :tool_calls])
  end

  defp get_config(opts) do
    case Application.get_env(:platform, Platform.Chaos.Agent) do
      nil ->
        raise "Platform.Chaos.Agent needs to be configured."

      config ->
        options =
          [
            base_url: Keyword.get(config, :llm_url, @localhost),
            plug: Keyword.get(config, :plug),
            receive_timeout: 60_000,
            headers: maybe_set_header(Keyword.get(config, :llm_api_key))
          ]
          |> Keyword.filter(fn {_, v} -> v != nil end)

        {Keyword.get(opts, :model, Keyword.fetch!(config, :llm_model)), options}
    end
  end

  defp prepare_history(%LLM{system: sys}, history) do
    [%{role: "system", content: sys} | :lists.reverse(history)]
  end

  defp maybe_set_header(nil), do: nil
  defp maybe_set_header(key), do: %{authorization: "Bearer " <> key}
end

defmodule Platform.LLM.Message do
  defstruct role: nil, content: nil, tool_calls: []

  def decode(%{"message" => message}) do
    decode(message)
  end

  def decode(%{"role" => "assistant", "content" => content, "tool_calls" => calls}),
    do: %Platform.LLM.Message{role: :assistant, content: content, tool_calls: calls}

  def decode(%{"role" => role, "content" => content}),
    do: %Platform.LLM.Message{role: role, content: content}

  def json_content(%Platform.LLM.Message{content: c}) do
    Jason.decode!(c)
  end
end
