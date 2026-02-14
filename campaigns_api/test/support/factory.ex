defmodule CampaignsApi.Factory do
  @moduledoc """
  ExMachina factory for generating test data.
  Uses simple, deterministic data generation without external dependencies.
  """

  use ExMachina.Ecto, repo: CampaignsApi.Repo

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Tenants.Tenant

  def tenant_factory do
    id = System.unique_integer([:positive])

    %Tenant{
      id: "tenant-#{id}",
      name: "Tenant #{id}",
      status: :active,
      deleted_at: nil
    }
  end

  def suspended_tenant_factory do
    struct!(
      tenant_factory(),
      %{status: :suspended}
    )
  end

  def deleted_tenant_factory do
    struct!(
      tenant_factory(),
      %{
        status: :deleted,
        deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    )
  end

  def campaign_factory do
    id = System.unique_integer([:positive])

    %Campaign{
      name: "Campaign #{id}",
      description: "Description for campaign #{id}",
      status: :active,
      start_time: nil,
      end_time: nil,
      tenant: build(:tenant)
    }
  end

  def campaign_with_dates_factory do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    start_time = DateTime.add(now, 3600, :second)
    end_time = DateTime.add(now, 7200, :second)

    struct!(
      campaign_factory(),
      %{
        start_time: start_time,
        end_time: end_time
      }
    )
  end

  def paused_campaign_factory do
    struct!(
      campaign_factory(),
      %{status: :paused}
    )
  end

  def jwt_token(tenant_id) do
    claims = %{"tenant_id" => tenant_id}
    header = %{"alg" => "HS256", "typ" => "JWT"}

    encoded_header = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    encoded_payload = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    signature = "dummy_signature"

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end
end
