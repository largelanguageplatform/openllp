defmodule Platform.Protocol.Error do
  alias Platform.Protocol.Error
  defstruct code: 0, id: nil, message: ""

  def serialize(%Error{} = err) do
    %{
      type: "error",
      id: err.id,
      code: err.code,
      message: err.message
    }
    |> Jason.encode!()
  end

  def deserialize_error() do
    %Error{code: 0, message: "Invalid JSON"}
  end

  def unauthenticated(id) do
    %Error{code: 1, id: id, message: "Not authenticated"}
  end

  def invalid_schema() do
    %Error{code: 2, message: "Invalid protocol schema"}
  end

  def invalid_presence_schema(id) do
    %Error{code: 3, id: id, message: "Invalid presence schema"}
  end

  def invalid_message_schema(id) do
    %Error{code: 4, id: id, message: "Invalid message schema"}
  end

  def general_error(id) do
    %Error{code: 5, id: id, message: "General server error, try again"}
  end

  def invalid_key(id) do
    %Error{code: 100, id: id, message: "Invalid key"}
  end

  def name_registered(id, name) do
    %Error{code: 101, id: id, message: "Name already registered: #{name}"}
  end

  def unrecognized_type(id, type) do
    %Error{code: 104, id: id, message: "Unrecognized type: #{type}"}
  end

  def missing_recipient(id) do
    %Error{code: 102, id: id, message: "Error processing message, missing recipient"}
  end

  def encryption_unsupported(id) do
    %Error{code: 105, id: id, message: "Agent does not support encrypted messages"}
  end

  def agent_not_found(id, name) do
    %Error{code: 106, id: id, message: "Agent could not be found online: #{name}"}
  end
end
