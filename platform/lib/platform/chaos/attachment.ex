defmodule Platform.Chaos.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attachments" do
    field :filename, :string
    field :location, :string
    field :bucket, :string
    belongs_to :organization, Platform.Account.Organization
    timestamps(type: :utc_datetime)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:filename, :location, :bucket])
    |> validate_required([:filename, :location, :bucket])
    |> validate_format(:filename, ~r/^[0-9a-zA-Z_\-. ]+$/)
    |> validate_length(:filename, max: 250, min: 5)
    |> unique_constraint(:location)
    |> foreign_key_constraint(:organization_id)
  end
end
