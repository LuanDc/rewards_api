defmodule CampaignsApiWeb.CampaignCriterionJSONTest do
  use CampaignsApiWeb.ConnCase

  alias CampaignsApi.Campaigns.CampaignCriterion
  alias CampaignsApiWeb.CampaignCriterionJSON

  describe "show/1" do
    test "renders campaign criterion without preloaded criterion" do
      campaign_criterion = %CampaignCriterion{
        id: Uniq.UUID.uuid7(),
        campaign_id: Uniq.UUID.uuid7(),
        criterion_id: Uniq.UUID.uuid7(),
        reward_points_amount: 100,
        periodicity: "daily",
        status: "active",
        criterion: nil,
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      }

      result = CampaignCriterionJSON.show(%{campaign_criterion: campaign_criterion})

      assert result.data.criterion == nil
      assert result.data.reward_points_amount == 100
    end
  end
end
