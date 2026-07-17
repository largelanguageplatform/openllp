defmodule Platform.Protocol.ToolCall do
  defstruct id: nil,
            version: 1,
            duration_ms: 0,
            name: "",
            parameters: "",
            result: "",
            threw_exception: false,
            to: nil

  def deserialize(id, map) do
    with {:ok, data} <- Map.fetch(map, "data"),
         {:ok, to} <- fetch(data, "to"),
         {:ok, duration} <- fetch(data, "duration_ms"),
         {:ok, name} <- fetch(data, "name"),
         {:ok, params} <- fetch(data, "parameters"),
         {:ok, result} <- fetch(data, "result"),
         {:ok, exception?} <- fetch(data, "threw_exception") do
      %__MODULE__{
        id: id,
        to: to,
        duration_ms: duration,
        name: name,
        parameters: params,
        result: result,
        threw_exception: exception?
      }
    end
  end

  def to_annotation_json(%__MODULE{} = tool) do
    %{
      type: "tool_call",
      version: 1,
      duration_ms: tool.duration_ms,
      name: tool.name,
      parameters: tool.parameters,
      result: tool.result,
      threw_exception: tool.threw_exception
    }
    |> Jason.encode!()
  end

  defp fetch(data, "duration_ms") do
    case Map.get(data, "duration_ms", {:ok, 0}) do
      duration when is_integer(duration) -> {:ok, duration}
      {:ok, duration} -> {:ok, duration}
      _else -> :error
    end
  end

  defp fetch(data, "threw_exception") do
    case Map.get(data, "threw_exception", false) do
      e when is_boolean(e) -> {:ok, e}
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _else -> :error
    end
  end

  defp fetch(data, "name") do
    case Map.get(data, "name", nil) do
      name when is_binary(name) -> {:ok, name}
      nil -> {:error, :requires_name}
      _else -> :error
    end
  end

  defp fetch(data, "parameters") do
    case Map.get(data, "parameters", "") do
      parameters when is_binary(parameters) -> {:ok, parameters}
      _else -> :error
    end
  end

  defp fetch(data, "result") do
    case Map.get(data, "result", "") do
      result when is_binary(result) -> {:ok, result}
      _else -> :error
    end
  end

  defp fetch(data, "to") do
    case Map.fetch(data, "to") do
      {:ok, to} when is_binary(to) -> {:ok, to}
      :error -> {:error, :missing_recipient}
      _else -> {:error, "to"}
    end
  end
end
