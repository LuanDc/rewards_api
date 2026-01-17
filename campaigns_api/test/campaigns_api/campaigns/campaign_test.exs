defmodule CampaignsApi.Campaigns.CampaignTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.Campaigns.Campaign

  describe "statuses/0" do
    test "returns list of valid campaign statuses" do
      statuses = Campaign.statuses()

      assert :not_started in statuses
      assert :active in statuses
      assert :paused in statuses
      assert :completed in statuses
      assert :cancelled in statuses
      assert length(statuses) == 5
    end
  end
end
