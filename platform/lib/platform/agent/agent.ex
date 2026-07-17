defmodule Platform.Agent.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agents" do
    field :name, :string
    field :description, :string
    field :status, Ecto.Enum, values: [public: 0, private: 1, disabled: 2]
    belongs_to :organization, Platform.Account.Organization
    belongs_to :domain, Platform.Agent.Domain
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:name, :description, :status, :domain_id])
    |> validate_required([:name])
  end
end
