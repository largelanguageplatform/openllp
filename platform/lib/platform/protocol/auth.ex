defmodule Platform.Protocol.Auth do
  alias Platform.Protocol.Auth
  alias Platform.Protocol.Error

  defstruct id: nil, name: nil, key: nil

  def serialize(id, session_id) do
    %{
      type: :authenticated,
      id: id,
      data: %{
        session_id: session_id
      }
    }
    |> Jason.encode!()
  end

  def deserialize(id, map) do
    with {:ok, name} <- Map.fetch(map, "name"),
         {:ok, key} <- Map.fetch(map, "key") do
      %Auth{id: id, name: name, key: key}
    else
      :error -> Error.invalid_schema()
    end
  end
end
