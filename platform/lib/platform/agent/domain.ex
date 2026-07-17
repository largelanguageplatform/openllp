defmodule Platform.Agent.Domain do
  use Ecto.Schema
  import Ecto.Changeset

  schema "domains" do
    field :name, :string
    field :description, :string
    belongs_to :parent_domain, Platform.Agent.Domain

    timestamps(type: :utc_datetime)
  end

  def changeset(domain, attrs) do
    domain
    |> cast(attrs, [:name, :description, :parent_domain_id])
    |> validate_required([:name, :description, :parent_domain_id])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:name)
  end
end
