defmodule Platform.Account.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field :name, :string
    field :email, :string
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :name_customized, :boolean, default: false
    field :is_internal, :boolean, default: false

    has_many :agents, Platform.Agent.Agent

    timestamps(type: :utc_datetime)
  end

  @doc """
  A organization changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(organization, attrs, opts \\ []) do
    organization
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  def name_changeset(organization, attrs, opts \\ []) do
    organization
    |> cast(attrs, [:name])
    |> validate_name(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Platform.Repo)
      |> unique_constraint(:email)
      |> validate_changed(:email)
    else
      changeset
    end
  end

  defp validate_changed(changeset, prop) do
    if get_field(changeset, prop) && get_change(changeset, prop) == nil do
      add_error(changeset, prop, "did not change")
    else
      changeset
    end
  end

  defp validate_name(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:name])
      |> validate_length(:name, max: 200)
      |> unsafe_validate_unique(:name, Platform.Repo)
      |> unique_constraint(:name)
      |> validate_changed(:name)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:name, Platform.Repo)
      |> unique_constraint(:email)
      |> validate_changed(:email)
    else
      changeset
    end
  end

  @doc """
  A changeset for updating the organization name.
  Unlike name_changeset, this doesn't require the name to be changed.
  Sets name_customized to true when name is updated.
  """
  def update_name_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
    |> unsafe_validate_unique(:name, Platform.Repo)
    |> unique_constraint(:name)
    |> put_change(:name_customized, true)
  end
end
