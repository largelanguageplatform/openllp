defmodule Platform.Protocol.Presence do
  alias Platform.Protocol.Presence
  alias Platform.Protocol.Error

  defstruct id: nil, status: :unavailable, from: nil, supports_encryption?: false

  def serialize(%Presence{} = p) do
    %{
      type: :presence,
      id: p.id,
      from: p.from,
      data: %{
        status: p.status,
        supports_encryption: p.supports_encryption?
      }
    }
    |> Jason.encode!()
  end

  def deserialize(id, map) do
    with {:ok, data} <- Map.fetch(map, "data"),
         {:ok, encryption?} <- fetch(data, "supports_encryption"),
         {:ok, status} <- fetch(data, "status") do
      %Presence{id: id, status: status, supports_encryption?: encryption?}
    else
      :error -> Error.invalid_presence_schema(id)
    end
  end

  defp fetch(data, "status") do
    case Map.fetch(data, "status") do
      {:ok, "available"} -> {:ok, :available}
      {:ok, "unavailable"} -> {:ok, :unavailable}
      _else -> :error
    end
  end

  defp fetch(data, "supports_encryption") do
    case Map.fetch(data, "supports_encryption") do
      {:ok, bool} when is_boolean(bool) -> {:ok, bool}
      :error -> {:ok, false}
      _other -> :error
    end
  end
end
