defmodule Platform.Account.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Platform.Account.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  The scope includes both the organization and the current member (for team
  support). The member's role determines what actions they can perform.
  """

  alias Platform.Account.Organization

  defstruct organization: nil, member: nil

  @doc """
  Creates a scope for the given organization and member.

  Returns nil if no organization is given.
  """
  def for_organization(%Organization{} = organization) do
    %__MODULE__{organization: organization, member: nil}
  end

  def for_organization(nil), do: nil
end
