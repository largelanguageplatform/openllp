defmodule Platform.Agent.APIKey do
  use Ecto.Schema
  import Ecto.Query
  alias Platform.Agent.APIKey

  @hash_algorithm :sha256
  @rand_size 32

  schema "api_keys" do
    field :name, :string
    field :enabled, :boolean, default: false
    field :key, :string, virtual: true, redact: true
    field :hashed_key, :string, redact: true
    belongs_to :organization, Platform.Account.Organization

    timestamps(type: :utc_datetime)
  end

  def build_api_key(organization, name) do
    data = :crypto.strong_rand_bytes(@rand_size)
    hash = :crypto.hash(@hash_algorithm, data)
    key = Base.encode64(data, padding: false)
    hashed_key = Base.encode64(hash, padding: false)

    %APIKey{
      name: name,
      enabled: true,
      key: key,
      hashed_key: hashed_key,
      organization_id: organization.id
    }
  end

  def verify_api_key_query(%APIKey{} = key) do
    verify_api_key_query(key.key)
  end

  def verify_api_key_query(api_key) do
    case Base.decode64(api_key, padding: false) do
      :error ->
        :error

      {:ok, decoded_key} ->
        hashed_key = :crypto.hash(@hash_algorithm, decoded_key) |> Base.encode64(padding: false)

        q =
          APIKey
          |> where(hashed_key: ^hashed_key)
          |> where(enabled: ^true)

        {:ok, q}
    end
  end
end
