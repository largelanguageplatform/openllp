defmodule Platform.Admin.DomainPersona do
  use Ecto.Schema
  import Ecto.Changeset

  schema "domain_personas" do
    field :name, :string
    field :prompt_text, :string
    field :max_turns, :integer, default: 10
    field :status, Ecto.Enum, values: [disabled: 0, enabled: 1]

    belongs_to :domain, Platform.Agent.Domain
    belongs_to :updated_by_admin, Platform.Admin.User, foreign_key: :updated_by

    timestamps(type: :utc_datetime)
  end

  def changeset(prompt, attrs) do
    prompt
    |> cast(attrs, [:name, :prompt_text, :domain_id, :max_turns, :status])
    |> validate_required([:name, :prompt_text, :domain_id])
    |> validate_number(:max_turns, greater_than: 0, less_than_or_equal_to: 20)
    |> unique_constraint(:name)
    |> foreign_key_constraint(:domain_id)
  end

  def update_changeset(prompt, attrs, admin) do
    prompt
    |> cast(attrs, [:name, :prompt_text, :domain_id, :max_turns, :status])
    |> validate_required([:prompt_text, :domain_id])
    |> validate_number(:max_turns, greater_than: 0, less_than_or_equal_to: 20)
    |> put_change(:updated_by, admin.id)
    |> foreign_key_constraint(:domain_id)
  end
end
