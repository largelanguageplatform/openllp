defmodule PlatformWeb.BundleJSON do
  alias Platform.Agent.Bundle

  @doc """
  Renders a single bundle.
  """
  def show(%{bundle: %Bundle{} = bundle}) do
    %{
      agent_id: bundle.agent,
      registration_id: bundle.registration_id,
      signed_prekey_id: bundle.signed_prekey_id,
      signed_prekey_public: bundle.signed_prekey_public,
      signed_prekey_signature: bundle.signed_prekey_signature,
      identity_key_public: bundle.identity_key_public
    }
  end
end
