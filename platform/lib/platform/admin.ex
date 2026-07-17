defmodule Platform.Admin do
  @moduledoc """
  The Admin context for managing admin users, domains, and domain personas.
  """

  import Ecto.Query, warn: false

  alias Platform.Repo
  alias Platform.Admin.{User, Token, DomainPersona}
  alias Platform.Agent.Domain

  # --- Authentication ---

  @doc """
  Gets an admin by email.
  """
  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets an admin by email and password.

  Returns the admin if credentials are valid, otherwise nil.
  """
  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = get_admin_by_email(email)
    if User.valid_password?(admin, password), do: admin
  end

  @doc """
  Generates a session token for an admin.
  """
  def generate_admin_session_token(admin) do
    {token, admin_token} = Token.build_session_token(admin)
    Repo.insert!(admin_token)
    token
  end

  @doc """
  Gets an admin by session token.

  Returns `{admin, token_inserted_at}` or `nil`.
  """
  def get_admin_by_session_token(token) do
    {:ok, query} = Token.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes an admin session token.
  Token is hashed before lookup.
  """
  def delete_admin_session_token(raw_token) do
    Repo.delete_all(Token.token_and_context_query(raw_token, "session"))
    :ok
  end

  # --- Domain Personas ---

  @doc """
  Lists all domain personas ordered by name.
  """
  def list_domain_personas do
    from(p in DomainPersona,
      order_by: [asc: p.name],
      preload: [:updated_by_admin, :domain]
    )
    |> Repo.all()
  end

  @doc """
  Lists all domains.
  """
  def list_domains do
    from(d in Domain,
      order_by: d.id,
      preload: [:parent_domain]
    )
    |> Repo.all()
  end

  @doc """
  Gets a domain by ID. Raises if not found.
  """
  def get_domain!(id) do
    Repo.get!(Domain, id)
  end

  @doc """
  Creates a new domain.
  """
  def create_domain(%Domain{} = parent, attrs) do
    %Domain{parent_domain_id: parent.id}
    |> Domain.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing domain.
  """
  def update_domain(%Domain{} = domain, attrs) do
    domain
    |> Domain.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for building domain forms.
  """
  def change_domain(%Domain{} = domain, attrs \\ %{}) do
    Domain.changeset(domain, attrs)
  end

  @doc """
  Gets a domain persona by ID.

  Raises if not found.
  """
  def get_domain_persona!(id) do
    Repo.get!(DomainPersona, id)
    |> Repo.preload([:updated_by_admin, :domain])
  end

  @doc """
  Creates a domain persona.
  """
  def create_domain_persona(attrs, admin) do
    %DomainPersona{}
    |> DomainPersona.changeset(attrs)
    |> Ecto.Changeset.put_change(:updated_by, admin.id)
    |> Repo.insert()
  end

  @doc """
  Updates a domain persona.
  """
  def update_domain_persona(%DomainPersona{} = prompt, attrs, admin) do
    prompt
    |> DomainPersona.update_changeset(attrs, admin)
    |> Repo.update()
  end

  # --- Admin User Management ---

  @doc """
  Creates an admin user with a temporary password.
  The admin will be forced to change password on first login.
  """
  def create_admin(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns true if admin must change their temporary password.
  """
  def must_change_password?(admin) do
    User.must_change_password?(admin)
  end

  @doc """
  Updates an admin's password and marks it as permanent.
  Deletes all existing session tokens for security.
  """
  def update_admin_password(admin, attrs) do
    changeset = User.password_change_changeset(admin, attrs)

    Repo.transaction(fn ->
      case Repo.update(changeset) do
        {:ok, admin} ->
          Repo.delete_all(from(t in Token, where: t.admin_id == ^admin.id))
          admin

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns a changeset for changing admin password (for forms).
  """
  def change_admin_password(admin, attrs \\ %{}) do
    User.password_change_changeset(admin, attrs, hash_password: false)
  end

  @doc """
  Lists all admin users ordered by email.
  """
  def list_admin_users do
    Repo.all(from u in User, order_by: u.email)
  end

  @doc """
  Gets an admin user by ID. Raises if not found.
  """
  def get_admin_user!(id) do
    Repo.get!(User, id)
  end

  @doc """
  Updates an admin user's email.
  """
  def update_admin_email(%User{} = user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for building admin email forms.
  """
  def change_admin_email(%User{} = user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end
end
