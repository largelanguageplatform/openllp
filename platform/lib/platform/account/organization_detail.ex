defmodule Platform.Account.OrganizationDetail do
  use Ecto.Schema

  schema "organizations_details" do
    field :thumbnail_url, :string
    field :description, :string
    field :short_description, :string
    belongs_to :organization, Platform.Account.Organization

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
