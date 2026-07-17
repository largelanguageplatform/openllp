defmodule Platform.Agent.Bundle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bundles" do
    field :agent, :string
    field :registration_id, :integer
    field :signed_prekey_id, :integer
    field :signed_prekey_public, :string
    field :signed_prekey_signature, :string
    field :identity_key_public, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bundle, attrs) do
    bundle
    |> cast(attrs, [
      :agent,
      :registration_id,
      :signed_prekey_id,
      :signed_prekey_public,
      :signed_prekey_signature,
      :identity_key_public
    ])
    |> validate_required([
      :agent,
      :registration_id,
      :signed_prekey_id,
      :signed_prekey_public,
      :signed_prekey_signature,
      :identity_key_public
    ])
  end

  @doc false
  def update_on_duplicate(bundle) do
    changes =
      bundle.changes
      |> Map.delete(:agent)
      |> Map.to_list()

    [set: changes]
  end
end
