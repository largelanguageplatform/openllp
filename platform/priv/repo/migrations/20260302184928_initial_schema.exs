defmodule Platform.Repo.Migrations.InitialSchema do
  use Ecto.Migration

  # Baseline migration for the open-source release. Its version equals the last
  # pre-squash migration, so databases migrated with the old history are already
  # up to date and skip it.

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:admin_users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :password_changed_at, :naive_datetime

      timestamps(type: :naive_datetime)
    end

    create unique_index(:admin_users, [:email])

    create table(:admin_tokens) do
      add :admin_id, references(:admin_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :authenticated_at, :naive_datetime

      timestamps(type: :naive_datetime, updated_at: false)
    end

    create index(:admin_tokens, [:admin_id])
    create unique_index(:admin_tokens, [:context, :token])

    create table(:organizations) do
      add :name, :string, null: false
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :naive_datetime

      timestamps(type: :naive_datetime)

      add :name_customized, :boolean, default: false, null: false
      add :is_internal, :boolean, default: false, null: false
    end

    create unique_index(:organizations, [:email])
    create unique_index(:organizations, [:name])

    create table(:organizations_tokens) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :naive_datetime

      timestamps(type: :naive_datetime, updated_at: false)
    end

    create index(:organizations_tokens, [:organization_id])
    create unique_index(:organizations_tokens, [:context, :token])

    create table(:organizations_details) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :thumbnail_url, :string
      add :description, :text
      add :short_description, :text

      timestamps(type: :naive_datetime)
    end

    create table(:organization_members) do
      add :organization_id, :bigint, null: false
      add :oauth_id, :string
      add :firstname, :string
      add :lastname, :string
      add :hashed_password, :string
      add :photo, :string
      add :email, :citext, null: false
      add :role, :string, default: "member", null: false
      add :status, :string, default: "invited", null: false
      add :invite_token_hash, :binary
      add :invite_expires_at, :naive_datetime
      add :invited_at, :naive_datetime
      add :joined_at, :naive_datetime

      timestamps(type: :naive_datetime)

      add :oauth_provider, :string
    end

    create index(:organization_members, [:invite_token_hash])
    create unique_index(:organization_members, [:organization_id, :email])
    create unique_index(:organization_members, [:organization_id, :oauth_id, :oauth_provider])

    create table(:member_tokens) do
      add :member_id, references(:organization_members, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :authenticated_at, :naive_datetime

      timestamps(type: :naive_datetime, updated_at: false)
    end

    create index(:member_tokens, [:member_id])
    create unique_index(:member_tokens, [:context, :token])

    create table(:api_keys) do
      add :organization_id, references(:organizations, on_delete: :delete_all, type: :integer)
      add :hashed_key, :string, null: false
      add :name, :string
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :naive_datetime)
    end

    create index(:api_keys, [:hashed_key])
    create index(:api_keys, [:organization_id, :enabled])

    create table(:domains) do
      add :name, :string
      add :description, :text

      timestamps(type: :naive_datetime)

      add :parent_domain_id, references(:domains, on_delete: :nilify_all, type: :integer)
    end

    create index(:domains, [:parent_domain_id])

    create table(:domain_personas) do
      add :name, :string, null: false
      add :domain_id, references(:domains, on_delete: :restrict), default: 0, null: false
      add :prompt_text, :text, null: false
      add :updated_by, references(:admin_users, on_delete: :nilify_all)

      timestamps(type: :naive_datetime)

      add :max_turns, :integer, default: 10, null: false
      add :status, :integer, default: 0, null: false
    end

    create unique_index(:domain_personas, [:name])

    # The application requires a root "general" domain with id 0
    # (e.g. Repo.get_by!(Domain, id: 0)); it must exist before any insert.
    execute(
      fn ->
        repo().query!(
          "INSERT INTO domains (id, name, description, inserted_at, updated_at) VALUES (0, $1, $2, now(), now())",
          ["general", domain_description(:general)]
        )
      end,
      fn -> repo().query!("DELETE FROM domains WHERE id = 0") end
    )

    for name <- ["finance", "other"] do
      execute(
        fn ->
          repo().query!(
            "INSERT INTO domains (name, description, parent_domain_id, inserted_at, updated_at) VALUES ($1, $2, 0, now(), now())",
            [name, domain_description(String.to_atom(name))]
          )
        end,
        fn -> repo().query!("DELETE FROM domains WHERE name = $1", [name]) end
      )
    end

    create table(:agents) do
      add :organization_id, references(:organizations, on_delete: :delete_all, type: :integer)
      add :name, :string, null: false
      add :description, :text
      add :status, :integer, default: 0

      timestamps(type: :naive_datetime)

      add :domain_id, references(:domains, type: :integer)
    end

    create index(:agents, [:name, :status])
    create unique_index(:agents, [:organization_id, :name])

    create table(:agent_sessions) do
      add :agent_id, references(:agents, on_delete: :delete_all, type: :integer)
      add :session, :string, null: false
      add :login_at, :naive_datetime, null: false
      add :logout_at, :naive_datetime

      timestamps(type: :naive_datetime)
    end

    create index(:agent_sessions, [:session])

    create table(:session_conversations) do
      add :agent_session_id, references(:agent_sessions, on_delete: :delete_all, type: :integer)
      add :test_result, :integer, default: 0, null: false
      add :display_name, :string, null: false

      timestamps(type: :naive_datetime)
    end

    create table(:conversation_messages) do
      add :session_conversation_id,
          references(:session_conversations, on_delete: :delete_all, type: :integer)

      add :prompt, :text
      add :direction, :integer, default: 0, null: false
      add :message_id, :string, null: false
      add :attachment, :string

      timestamps(type: :naive_datetime)

      add :annotation_kind, :integer
      add :annotation_details, :json
    end

    create index(:conversation_messages, [:annotation_kind])
    create index(:conversation_messages, [:message_id])

    create table(:attachments) do
      add :filename, :string
      add :location, :string
      add :bucket, :string

      timestamps(type: :naive_datetime)

      add :organization_id, references(:organizations, type: :integer)
    end

    create unique_index(:attachments, [:location])

    create table(:bundles) do
      add :agent, :string
      add :registration_id, :bigint
      add :signed_prekey_id, :bigint
      add :signed_prekey_public, :string
      add :signed_prekey_signature, :string
      add :identity_key_public, :string

      timestamps(type: :naive_datetime)
    end

    create unique_index(:bundles, [:agent])
  end

  defp domain_description(:general) do
    "If there are no skills that match what the user provided, then the skill should
    be marked as 'general'."
  end

  defp domain_description(:finance) do
    """
    Finance is the management of money, assets, and credit, involving activities
    like investing, budgeting, saving, and borrowing to achieve financial goals
    for individuals, businesses, and governments. It's essentially the science
    and art of allocating resources effectively, encompassing personal finance
    (households), corporate finance (companies), and public finance (governments).
    """
  end

  defp domain_description(:other) do
    """
    If there are no skills that match what the user provided, then the skill should
    be marked as 'other'.
    """
  end
end
