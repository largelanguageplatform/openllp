defmodule Platform.Admin.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :password_changed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating an admin with a temporary password.
  `password_changed_at` is left nil to force password change on first login.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  Changeset for changing password after first login.
  Sets `password_changed_at` to mark password as permanent.
  """
  def password_change_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_password(opts)
    |> put_change(:password_changed_at, DateTime.utc_now(:second))
  end

  @doc """
  Returns true if admin must change their temporary password.
  """
  def must_change_password?(%__MODULE__{password_changed_at: nil}), do: true
  def must_change_password?(%__MODULE__{}), do: false

  @doc """
  Changeset for updating an admin's email address.
  Includes uniqueness validation.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email([])
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Platform.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end
end
