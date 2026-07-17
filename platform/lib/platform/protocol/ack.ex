defmodule Platform.Protocol.Ack do
  def serialize(id) do
    %{
      type: "ack",
      id: id
    }
    |> Jason.encode!()
  end
end
