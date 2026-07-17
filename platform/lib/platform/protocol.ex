defmodule Platform.Protocol do
  alias Platform.Protocol.{Auth, Error, Message, Presence, ToolCall}

  def from_map(map) when is_map(map) do
    with {:ok, id} <- Map.fetch(map, "id"),
         {:ok, type} <- Map.fetch(map, "type") do
      deserialize(type, id, map)
    else
      :error -> Error.invalid_schema()
    end
  end

  def from_map(_else), do: Error.invalid_schema()

  def deserialize("authenticate", id, map), do: Auth.deserialize(id, map)
  def deserialize("presence", id, map), do: Presence.deserialize(id, map)
  def deserialize("message", id, map), do: Message.deserialize(id, map)
  def deserialize("tool_call", id, map), do: ToolCall.deserialize(id, map)
  def deserialize(unknown, id, _map), do: Error.unrecognized_type(id, unknown)

  def serialize(%Presence{} = p), do: Presence.serialize(p)
  def serialize(%Message{} = m), do: Message.serialize(m)

  def ack(%{id: id}), do: %{type: "ack", id: id}
end
