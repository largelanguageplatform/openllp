defmodule Platform.Conversations.ConversationMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversation_messages" do
    field :prompt, :string
    field :direction, Ecto.Enum, values: [inbound: 0, outbound: 1, annotation: 2]
    field :annotation_kind, Ecto.Enum, values: [comment: 0, error: 1, tool_call: 2]
    field :annotation_details, :string
    field :message_id, :string
    field :attachment, :string

    belongs_to :session_conversation, Platform.Conversations.SessionConversation
    timestamps(type: :utc_datetime)
  end

  def message_changeset(conversation_message, attrs) do
    conversation_message
    |> cast(attrs, [
      :session_conversation_id,
      :prompt,
      :direction,
      :message_id,
      :attachment
    ])
    |> validate_required([:session_conversation_id, :prompt, :direction, :message_id])
    |> validate_inclusion(:direction, [:inbound, :outbound])
    |> validate_length(:attachment, min: 5, max: 250)
    |> validate_format(:attachment, ~r/^[0-9a-zA-Z_\-. ]+$/)
    |> foreign_key_constraint(:session_conversation_id)
  end

  def annotation_changeset(conversation_message, attrs, kind) do
    conversation_message
    |> cast(attrs, [
      :session_conversation_id,
      :direction,
      :message_id,
      :annotation_kind,
      :annotation_details,
      :message_id
    ])
    |> validate_required([
      :session_conversation_id,
      :direction,
      :annotation_kind,
      :annotation_details,
      :message_id
    ])
    |> validate_inclusion(:direction, [:annotation])
    |> validate_inclusion(:annotation_kind, [:comment, :error, :tool_call])
    |> validate_length(:annotation_details, max: 2048)
    |> validate_json_schema(kind)
    |> foreign_key_constraint(:session_conversation_id)
  end

  def validate_json_schema(changeset, kind) do
    if get_field(changeset, :annotation_details) == nil do
      changeset
    else
      with details <- fetch_field!(changeset, :annotation_details),
           {:ok, decoded} <- Jason.decode(details),
           :ok <- ExJsonSchema.Validator.validate(json_schema(kind), decoded) do
        changeset
      else
        {:error, %Jason.DecodeError{}} ->
          add_error(changeset, :annotation_details, "not JSON decodeable")

        {:error, validation_errors} ->
          errors =
            validation_errors
            |> Enum.map(fn {description, _path} -> description end)
            |> Enum.join(" ")

          add_error(changeset, :annotation_details, "JSON schema errors: #{errors}")
      end
    end
  end

  def json_schema(:tool_call) do
    %{
      "type" => "object",
      "properties" => %{
        "type" => %{
          "enum" => ["tool_call"]
        },
        "version" => %{
          "type" => "integer",
          "minimum" => 1,
          "maximum" => 1
        },
        "duration_ms" => %{
          "type" => "integer",
          "minimum" => 0
        },
        "name" => %{
          "type" => "string"
        },
        "parameters" => %{
          "type" => "string"
        },
        "result" => %{
          "type" => "string"
        },
        "threw_exception" => %{
          "type" => "boolean"
        }
      },
      "required" => ["type", "version", "name", "parameters", "duration_ms", "threw_exception"]
    }
  end
end
