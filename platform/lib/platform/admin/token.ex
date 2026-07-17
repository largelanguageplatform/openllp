defmodule Platform.Admin.Token do
  use Ecto.Schema
  import Ecto.Query, warn: false

  @hash_algorithm :sha256
  @rand_size 32
  @session_validity_in_days 14

  schema "admin_tokens" do
    field :token, :binary
    field :context, :string
    field :authenticated_at, :utc_datetime

    belongs_to :admin, Platform.Admin.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a session token.

  Returns `{raw_token, token_struct}` where:
  - `raw_token` is sent to client (cookie)
  - `token_struct.token` contains the HASHED token for DB storage

  This ensures a DB leak doesn't expose usable tokens.
  """
  def build_session_token(admin) do
    raw_token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, raw_token)
    dt = DateTime.utc_now(:second)

    {raw_token,
     %__MODULE__{
       token: hashed_token,
       context: "session",
       admin_id: admin.id,
       authenticated_at: dt
     }}
  end

  @doc """
  Verifies a session token by hashing the raw token and comparing.
  """
  def verify_session_token_query(raw_token) do
    hashed_token = :crypto.hash(@hash_algorithm, raw_token)

    query =
      from t in by_token_and_context_query(hashed_token, "session"),
        join: admin in assoc(t, :admin),
        where: t.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{admin | authenticated_at: t.authenticated_at}, t.inserted_at}

    {:ok, query}
  end

  @doc """
  Returns query for deleting a token by raw token value.
  """
  def token_and_context_query(raw_token, context) do
    hashed_token = :crypto.hash(@hash_algorithm, raw_token)
    by_token_and_context_query(hashed_token, context)
  end

  defp by_token_and_context_query(hashed_token, context) do
    from __MODULE__, where: [token: ^hashed_token, context: ^context]
  end
end
