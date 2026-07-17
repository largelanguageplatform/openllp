defmodule Platform.Protocol.Message do
  alias Platform.Protocol.Message
  alias Platform.Protocol.Error

  defstruct id: nil,
            from: nil,
            encrypted?: false,
            to: nil,
            prompt: nil,
            attachment: nil,
            filename: nil

  def serialize(%Message{} = msg) do
    %{
      type: :message,
      id: msg.id,
      from: msg.from,
      data: %{
        to: msg.to,
        encrypted: msg.encrypted?,
        prompt: msg.prompt,
        attachment_url: msg.attachment
      }
    }
    |> Jason.encode!()
  end

  def deserialize(id, map) do
    with {:ok, data} <- Map.fetch(map, "data"),
         {:ok, to} <- fetch(data, "to"),
         {:ok, encrypted?} <- fetch(data, "encrypted"),
         {:ok, prompt} <- fetch(data, "prompt") do
      %Message{
        id: id,
        from: Map.get(map, "from"),
        encrypted?: encrypted?,
        to: to,
        prompt: prompt,
        attachment: Map.get(map, "attachment_url")
      }
    else
      :error -> Error.invalid_message_schema(id)
      {:error, :missing_recipient} -> Error.missing_recipient(id)
    end
  end

  def set_attachment(%Message{} = msg, nil), do: msg

  def set_attachment(%Message{} = msg, {url, filename}) do
    %Message{msg | filename: filename, attachment: url}
  end

  defp fetch(data, "encrypted") do
    case Map.fetch(data, "encrypted") do
      {:ok, bool} when is_boolean(bool) -> {:ok, bool}
      {:ok, "true"} -> {:ok, true}
      {:ok, "false"} -> {:ok, false}
      _else -> :error
    end
  end

  defp fetch(data, "to") do
    case Map.fetch(data, "to") do
      {:ok, to} when is_binary(to) -> {:ok, to}
      :error -> {:error, :missing_recipient}
      _else -> :error
    end
  end

  defp fetch(data, "prompt") do
    case Map.fetch(data, "prompt") do
      {:ok, prompt} when is_binary(prompt) -> {:ok, prompt}
      _else -> :error
    end
  end
end
