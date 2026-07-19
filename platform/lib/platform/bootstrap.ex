defmodule Platform.Bootstrap do
  @moduledoc """
  Creates the single local organization this self-hosted instance operates as.

  The open-source platform is single-tenant: there are no user accounts and no
  login. Every web request runs in the scope of this bootstrap organization
  (see `PlatformWeb.OrganizationAuth.assign_bootstrap_scope/2`); the only
  credential in the system is the agent API key.

  Runs synchronously at application start, after the Repo (and after release
  migrations, which `bin/server` applies before boot). Idempotent across
  restarts; the organization name is configurable via `BOOTSTRAP_ORG_NAME`.
  """

  import Ecto.Query, only: [from: 2]

  alias Platform.Account.Organization
  alias Platform.Admin.DomainPersona
  alias Platform.Agent.Domain
  alias Platform.Repo

  @doc false
  def child_spec(_arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :transient}
  end

  @doc false
  def start_link do
    ensure!()
    :ignore
  end

  @doc "Fetches (creating if needed) the bootstrap organization."
  def ensure! do
    organization = first_organization() || create!()
    ensure_example_personas()
    organization
  end

  @doc "Returns the bootstrap organization. Raises if the platform has not booted."
  def organization! do
    first_organization() || raise "bootstrap organization missing — did the app boot?"
  end

  # Single-tenant: THE organization is the first (and normally only) row.
  # Looking it up positionally rather than by name keeps renames safe.
  defp first_organization do
    Repo.one(from o in Organization, order_by: [asc: o.id], limit: 1)
  end

  defp create! do
    %Organization{}
    |> Ecto.Changeset.change(
      name: org_name(),
      email: "ops@localhost",
      confirmed_at: DateTime.utc_now(:second)
    )
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :name)
    |> case do
      %Organization{id: nil} -> first_organization()
      organization -> organization
    end
  end

  defp org_name, do: System.get_env("BOOTSTRAP_ORG_NAME", "local")

  # Example chaos-test personas, provisioned once when the personas table is
  # empty so fresh installs (where seeds never run) have working examples in
  # /admin/prompts. Operators can edit or delete them freely; an emptied table
  # is only re-seeded if it is empty again at next boot.
  defp ensure_example_personas do
    if Repo.aggregate(DomainPersona, :count) == 0 do
      finance = Repo.get_by!(Domain, name: "finance")

      meteorology =
        ensure_domain("meteorology", """
        Meteorology is the scientific study of the Earth's atmosphere, focusing on weather processes,
        forecasting, and atmospheric phenomena, primarily within the troposphere.
        """)

      for attrs <- example_personas(finance, meteorology) do
        Repo.insert!(struct!(DomainPersona, attrs), on_conflict: :nothing, conflict_target: :name)
      end
    end

    :ok
  end

  defp ensure_domain(name, description) do
    Repo.get_by(Domain, name: name) ||
      Repo.insert!(%Domain{name: name, description: description, parent_domain_id: 0})
  end

  defp example_personas(finance, meteorology) do
    [
      %{
        domain_id: meteorology.id,
        name: "weather",
        prompt_text: """
        You are talking to a meteorologist and need to know what the weather is currently in San Francisco.
        """,
        max_turns: 3,
        status: :enabled
      },
      %{
        domain_id: finance.id,
        name: "invoice",
        prompt_text: """
        You work in finance for a company called Construction Corporation. You are using a financial agent to look over
        your invoices. You will need to generate a pdf of an invoice and ask questions about the invoice to
        ensure the agent understands what it's looking at. You MUST be succinct in your questioning as the
        financial agent is short on time and has many clients to see this week.
        """,
        max_turns: 5,
        status: :enabled
      },
      %{
        domain_id: finance.id,
        name: "tax_noob",
        prompt_text: """
        Let's roleplay: You are a taxpayer desperate to file your taxes by the upcoming deadline. You are
        overwhelmed and confused by all of the paperwork you have to fill out and need
        to ask some clarifying questions. I am going to provide you a financial agent with a description
        of what they can do. You have exercised ISO stock options and don't understand the tax implications
        and what forms to fill out. If the answer is unclear, provide follow up questions. You MUST be
        succinct in your questioning as the financial agent is short on time and has many clients to see this week.
        """,
        max_turns: 5,
        status: :enabled
      }
    ]
  end
end
