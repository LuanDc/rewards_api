defmodule CampaignsApi.CampaignsTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.Campaigns

  @tenant "tenant-test-123"

  describe "list_campaigns/0" do
    test "returns all campaigns regardless of tenant" do
      campaign1 = insert(:campaign, tenant: @tenant)
      campaign2 = insert(:campaign, tenant: "another-tenant")

      campaigns = Campaigns.list_campaigns()

      assert length(campaigns) >= 2
      assert Enum.any?(campaigns, fn c -> c.id == campaign1.id end)
      assert Enum.any?(campaigns, fn c -> c.id == campaign2.id end)
    end
  end

  describe "get_campaign!/1" do
    test "returns the campaign with given id" do
      campaign = insert(:campaign, tenant: @tenant)

      found_campaign = Campaigns.get_campaign!(campaign.id)

      assert found_campaign.id == campaign.id
      assert found_campaign.name == campaign.name
    end

    test "raises Ecto.NoResultsError when campaign does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Campaigns.get_campaign!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_campaign_by_tenant/2" do
    test "returns nil when campaign belongs to different tenant" do
      campaign = insert(:campaign, tenant: "different-tenant")

      result = Campaigns.get_campaign_by_tenant(campaign.id, @tenant)

      assert result == nil
    end
  end

  describe "update_campaign/2" do
    test "returns error when finished_at is before started_at" do
      campaign = insert(:campaign, tenant: @tenant)
      started_at = ~U[2026-01-15 10:00:00Z]
      finished_at = ~U[2026-01-15 09:00:00Z]

      {:error, changeset} =
        Campaigns.update_campaign(
          campaign,
          %{started_at: started_at, finished_at: finished_at}
        )

      assert %{finished_at: ["must be after started_at"]} = errors_on(changeset)
    end

    test "returns error when finished_at equals started_at" do
      campaign = insert(:campaign, tenant: @tenant)
      same_time = ~U[2026-01-15 10:00:00Z]

      {:error, changeset} =
        Campaigns.update_campaign(
          campaign,
          %{started_at: same_time, finished_at: same_time}
        )

      assert %{finished_at: ["must be after started_at"]} = errors_on(changeset)
    end

    test "successfully updates when finished_at is after started_at" do
      campaign = insert(:campaign, tenant: @tenant)
      started_at = ~U[2026-01-15 10:00:00.000000Z]
      finished_at = ~U[2026-01-15 12:00:00.000000Z]

      {:ok, updated_campaign} =
        Campaigns.update_campaign(
          campaign,
          %{started_at: started_at, finished_at: finished_at}
        )

      assert updated_campaign.started_at == started_at
      assert updated_campaign.finished_at == finished_at
    end
  end

  describe "change_campaign/2" do
    test "returns a campaign changeset" do
      campaign = insert(:campaign, tenant: @tenant)

      changeset = Campaigns.change_campaign(campaign, %{name: "New Name"})

      assert %Ecto.Changeset{} = changeset
      assert changeset.data.id == campaign.id
    end
  end
end
