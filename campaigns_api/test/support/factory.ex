defmodule CampaignsApi.Factory do
  @moduledoc """
  ExMachina factory for generating test data.
  """

  use ExMachina.Ecto, repo: CampaignsApi.Repo

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Tenants.Tenant

  def tenant_factory do
    %Tenant{
      id: "tenant-#{System.unique_integer([:positive])}",
      name: sequence(:tenant_name, &"Tenant #{&1}"),
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
    %Campaign{
      name: sequence(:campaign_name, &"Campaign #{&1}"),
      description: "Test campaign description",
      status: :active,
      start_time: nil,
      end_time: nil,
      tenant: build(:tenant)
    }
  end

  def campaign_with_dates_factory do
    start_time = DateTime.utc_now() |> DateTime.truncate(:second)
    end_time = DateTime.add(start_time, 86_400, :second)

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
