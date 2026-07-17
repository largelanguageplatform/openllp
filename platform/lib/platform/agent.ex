defmodule Platform.Agent do
  @moduledoc """
  The Agent context.
  """

  import Ecto.Query, warn: false
  alias Platform.Account.Organization
  alias Platform.Repo

  alias Platform.Agent.Domain
  alias Platform.Agent.{Agent, APIKey, Bundle}
  alias Platform.Account.Scope

  def register_agent(%Scope{organization: org}, name, description) do
    %Agent{organization: org}
    |> Agent.changeset(%{name: name, description: description, status: :public})
    |> Repo.insert()
  end

  def set_description(agent, description) do
    agent
    |> Agent.changeset(%{description: description})
    |> Repo.update()
  end

  def maybe_register_agent(%Organization{} = org, name) do
    exists =
      Agent
      |> where(organization_id: ^org.id)
      |> where(name: ^name)
      |> Repo.all()

    case exists do
      [] ->
        %Agent{organization_id: org.id}
        |> Agent.changeset(%{name: name, description: "", status: status(org)})
        |> Repo.insert()

      [agent] ->
        {:ok, agent}
    end
  end

  defp status(%Organization{is_internal: true}), do: :private
  defp status(_org), do: :public

  def list_agents(%Scope{organization: org}) do
    Repo.all_by(Agent, organization_id: org.id)
  end

  def get_agent_by_name(%Scope{organization: org}, name) do
    Agent
    |> where(organization_id: ^org.id)
    |> where(name: ^name)
    |> Repo.one()
  end

  def get_agent_by_id(id) do
    Agent
    |> preload(:organization)
    |> Repo.get_by(id: id)
  end

  def get_domain_by_id!(id) do
    Repo.get!(Domain, id)
  end

  def get_domain(%Agent{domain_id: nil}), do: nil

  def get_domain(%Agent{domain_id: sid}) do
    Domain
    |> Repo.get_by(id: sid)
  end

  def set_domain(%Agent{} = a, %Domain{} = domain) do
    a
    |> Agent.changeset(%{domain_id: domain.id})
    |> Repo.update()
  end

  @doc """
  Gets a single bundle.

  Raises `Ecto.NoResultsError` if the Bundle does not exist.

  ## Examples

      iex> get_bundle!(123)
      %Bundle{}

      iex> get_bundle!(456)
      nil

  """
  def get_bundle!(id) do
    Bundle
    |> where(agent: ^id)
    |> Repo.one()
  end

  @doc """
  Creates a bundle.

  ## Examples

      iex> create_bundle(%{field: value})
      {:ok, %Bundle{}}

      iex> create_bundle(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_bundle(attrs) do
    b =
      %Bundle{}
      |> Bundle.changeset(attrs)

    Repo.insert(b, on_conflict: Bundle.update_on_duplicate(b), conflict_target: :agent)
  end

  @doc """
  Deletes a bundle.

  ## Examples

      iex> delete_bundle(bundle.agent)
      :ok

  """
  def delete_bundle(id) do
    Bundle
    |> where(agent: ^id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bundle changes.

  ## Examples

      iex> change_bundle(bundle)
      %Ecto.Changeset{data: %Bundle{}}

  """
  def change_bundle(%Bundle{} = bundle, attrs \\ %{}) do
    Bundle.changeset(bundle, attrs)
  end

  def generate_api_key(%Scope{} = scope) do
    APIKey.build_api_key(scope.organization, "default")
    |> Repo.insert()
  end

  def get_api_key(api_key) do
    {:ok, q} = APIKey.verify_api_key_query(api_key)

    q
    |> preload(:organization)
    |> Repo.one()
  end

  @doc """
  Returns the list of api_keys.

  ## Examples

      iex> list_api_keys(scope)
      [%APIKey{}, ...]

  """
  def list_api_keys(%Scope{} = scope) do
    APIKey
    |> where(organization_id: ^scope.organization.id, enabled: ^true)
    |> Repo.all()
  end

  @doc """
  Returns true if the organization has at least one API key.

  ## Examples

      iex> has_api_key?(scope)
      true

  """
  def has_api_key?(%Scope{} = scope) do
    list_api_keys(scope) != []
  end

  @doc """
  Gets a single api_key.

  Raises `Ecto.NoResultsError` if the Api key does not exist.

  ## Examples

      iex> get_api_key!(scope, 123)
      %APIKey{}

      iex> get_api_key!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_api_key!(%Scope{} = scope, id) do
    Repo.get_by!(APIKey, id: id, organization_id: scope.organization.id)
  end

  @doc """
  Deletes a api_key.

  ## Examples

      iex> delete_api_keys(scope)
      :ok

  """
  def delete_api_keys(%Scope{} = scope) do
    APIKey
    |> where(organization_id: ^scope.organization.id)
    |> Repo.delete_all()

    :ok
  end
end
