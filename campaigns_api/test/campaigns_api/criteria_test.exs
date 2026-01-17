defmodule CampaignsApi.CriteriaTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.Criteria
  alias CampaignsApi.Factory

  describe "list_criteria/0" do
    test "returns all criteria" do
      criterion1 = Factory.insert(:criterion)
      criterion2 = Factory.insert(:criterion)

      criteria = Criteria.list_criteria()

      assert length(criteria) == 2
      assert Enum.any?(criteria, &(&1.id == criterion1.id))
      assert Enum.any?(criteria, &(&1.id == criterion2.id))
    end

    test "returns empty list when no criteria exist" do
      assert Criteria.list_criteria() == []
    end
  end

  describe "list_active_criteria/0" do
    test "returns only active criteria" do
      active_criterion = Factory.insert(:criterion, status: "active")
      _inactive_criterion = Factory.insert(:criterion, status: "inactive")

      criteria = Criteria.list_active_criteria()

      assert length(criteria) == 1
      assert hd(criteria).id == active_criterion.id
      assert hd(criteria).status == "active"
    end

    test "returns empty list when no active criteria exist" do
      Factory.insert(:criterion, status: "inactive")

      assert Criteria.list_active_criteria() == []
    end
  end

  describe "get_criterion!/1" do
    test "returns the criterion with given id" do
      criterion = Factory.insert(:criterion)

      retrieved = Criteria.get_criterion!(criterion.id)

      assert retrieved.id == criterion.id
      assert retrieved.name == criterion.name
    end

    test "raises Ecto.NoResultsError when criterion does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Criteria.get_criterion!(Uniq.UUID.uuid7())
      end
    end
  end

  describe "get_criterion/1" do
    test "returns the criterion with given id" do
      criterion = Factory.insert(:criterion)

      retrieved = Criteria.get_criterion(criterion.id)

      assert retrieved.id == criterion.id
      assert retrieved.name == criterion.name
    end

    test "returns nil when criterion does not exist" do
      assert Criteria.get_criterion(Uniq.UUID.uuid7()) == nil
    end
  end

  describe "create_criterion/1" do
    test "creates a criterion with valid attributes" do
      attrs = %{
        name: "Daily Login",
        status: "active",
        description: "User must login daily"
      }

      assert {:ok, criterion} = Criteria.create_criterion(attrs)
      assert criterion.name == "Daily Login"
      assert criterion.status == "active"
      assert criterion.description == "User must login daily"
      assert criterion.id != nil
    end

    test "creates a criterion with minimal attributes" do
      attrs = %{
        name: "Simple Criterion",
        status: "active"
      }

      assert {:ok, criterion} = Criteria.create_criterion(attrs)
      assert criterion.name == "Simple Criterion"
      assert criterion.description == nil
    end

    test "returns error changeset when name is missing" do
      attrs = %{status: "active"}

      assert {:error, changeset} = Criteria.create_criterion(attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error changeset when status is invalid" do
      attrs = %{name: "Test", status: "invalid"}

      assert {:error, changeset} = Criteria.create_criterion(attrs)
      assert "is invalid" in errors_on(changeset).status
    end

    test "returns error changeset when name is not unique" do
      Factory.insert(:criterion, name: "Unique Name")
      attrs = %{name: "Unique Name", status: "active"}

      assert {:error, changeset} = Criteria.create_criterion(attrs)
      assert "has already been taken" in errors_on(changeset).name
    end
  end

  describe "update_criterion/2" do
    test "updates the criterion with valid attributes" do
      criterion = Factory.insert(:criterion)
      attrs = %{name: "Updated Name", description: "Updated description"}

      assert {:ok, updated} = Criteria.update_criterion(criterion, attrs)
      assert updated.name == "Updated Name"
      assert updated.description == "Updated description"
    end

    test "updates criterion status" do
      criterion = Factory.insert(:criterion, status: "active")

      assert {:ok, updated} = Criteria.update_criterion(criterion, %{status: "inactive"})
      assert updated.status == "inactive"
    end

    test "returns error changeset when attributes are invalid" do
      criterion = Factory.insert(:criterion)

      assert {:error, changeset} = Criteria.update_criterion(criterion, %{name: nil})
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "delete_criterion/1" do
    test "deletes the criterion" do
      criterion = Factory.insert(:criterion)

      assert {:ok, deleted} = Criteria.delete_criterion(criterion)
      assert deleted.id == criterion.id
      assert Criteria.get_criterion(criterion.id) == nil
    end
  end

  describe "change_criterion/2" do
    test "returns a criterion changeset" do
      criterion = Factory.insert(:criterion)

      changeset = Criteria.change_criterion(criterion)

      assert %Ecto.Changeset{} = changeset
      assert changeset.data == criterion
    end

    test "returns a changeset with changes" do
      criterion = Factory.insert(:criterion)
      attrs = %{name: "New Name"}

      changeset = Criteria.change_criterion(criterion, attrs)

      assert changeset.changes.name == "New Name"
    end
  end

  describe "associate_criterion_to_campaign/1" do
    test "associates a criterion to a campaign with valid attributes" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      attrs = %{
        campaign_id: campaign.id,
        criterion_id: criterion.id,
        status: "active",
        reward_points_amount: 150,
        periodicity: "0 0 * * *"
      }

      assert {:ok, campaign_criterion} = Criteria.associate_criterion_to_campaign(attrs)
      assert campaign_criterion.campaign_id == campaign.id
      assert campaign_criterion.criterion_id == criterion.id
      assert campaign_criterion.reward_points_amount == 150
      assert campaign_criterion.periodicity == "0 0 * * *"
    end

    test "returns error when campaign_id is missing" do
      criterion = Factory.insert(:criterion)

      attrs = %{
        criterion_id: criterion.id,
        reward_points_amount: 100,
        status: "active"
      }

      assert {:error, changeset} = Criteria.associate_criterion_to_campaign(attrs)
      assert "can't be blank" in errors_on(changeset).campaign_id
    end

    test "returns error when reward_points_amount is negative" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      attrs = %{
        campaign_id: campaign.id,
        criterion_id: criterion.id,
        reward_points_amount: -10,
        status: "active"
      }

      assert {:error, changeset} = Criteria.associate_criterion_to_campaign(attrs)
      assert "must be greater than 0" in errors_on(changeset).reward_points_amount
    end

    test "returns error when association already exists" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      attrs = %{
        campaign_id: campaign.id,
        criterion_id: criterion.id,
        reward_points_amount: 100,
        status: "active"
      }

      assert {:ok, _} = Criteria.associate_criterion_to_campaign(attrs)
      assert {:error, changeset} = Criteria.associate_criterion_to_campaign(attrs)

      assert "has already been taken" in errors_on(changeset).campaign_id or
               "has already been taken" in errors_on(changeset).criterion_id
    end
  end

  describe "update_campaign_criterion/2" do
    test "updates a campaign criterion association" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      {:ok, campaign_criterion} =
        Criteria.associate_criterion_to_campaign(%{
          campaign_id: campaign.id,
          criterion_id: criterion.id,
          reward_points_amount: 100,
          status: "active"
        })

      attrs = %{reward_points_amount: 200, periodicity: "0 12 * * *"}

      assert {:ok, updated} = Criteria.update_campaign_criterion(campaign_criterion, attrs)
      assert updated.reward_points_amount == 200
      assert updated.periodicity == "0 12 * * *"
    end

    test "returns error when reward_points_amount is invalid" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      {:ok, campaign_criterion} =
        Criteria.associate_criterion_to_campaign(%{
          campaign_id: campaign.id,
          criterion_id: criterion.id,
          reward_points_amount: 100,
          status: "active"
        })

      assert {:error, changeset} =
               Criteria.update_campaign_criterion(campaign_criterion, %{reward_points_amount: -5})

      assert "must be greater than 0" in errors_on(changeset).reward_points_amount
    end
  end

  describe "remove_criterion_from_campaign/1" do
    test "removes a criterion association from a campaign" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      {:ok, campaign_criterion} =
        Criteria.associate_criterion_to_campaign(%{
          campaign_id: campaign.id,
          criterion_id: criterion.id,
          reward_points_amount: 100,
          status: "active"
        })

      assert {:ok, deleted} = Criteria.remove_criterion_from_campaign(campaign_criterion)
      assert deleted.id == campaign_criterion.id

      assert Criteria.get_campaign_criterion(campaign.id, criterion.id) == nil
    end
  end

  describe "get_campaign_criterion/2" do
    test "returns campaign criterion association" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      {:ok, campaign_criterion} =
        Criteria.associate_criterion_to_campaign(%{
          campaign_id: campaign.id,
          criterion_id: criterion.id,
          reward_points_amount: 100,
          status: "active"
        })

      retrieved = Criteria.get_campaign_criterion(campaign.id, criterion.id)

      assert retrieved.id == campaign_criterion.id
      assert retrieved.campaign_id == campaign.id
      assert retrieved.criterion_id == criterion.id
    end

    test "returns nil when association does not exist" do
      campaign = Factory.insert(:campaign)
      criterion = Factory.insert(:criterion)

      assert Criteria.get_campaign_criterion(campaign.id, criterion.id) == nil
    end
  end

  describe "list_campaign_criteria/1" do
    test "returns all criteria associated with a campaign" do
      campaign = Factory.insert(:campaign)
      criterion1 = Factory.insert(:criterion)
      criterion2 = Factory.insert(:criterion)

      {:ok, _} =
        Criteria.associate_criterion_to_campaign(%{
          campaign_id: campaign.id,
          criterion_id: criterion1.id,
          reward_points_amount: 100,
          status: "active"
        })

      {:ok, _} =
        Criteria.associate_criterion_to_campaign(%{
          campaign_id: campaign.id,
          criterion_id: criterion2.id,
          reward_points_amount: 200,
          status: "active"
        })

      campaign_criteria = Criteria.list_campaign_criteria(campaign.id)

      assert length(campaign_criteria) == 2
      assert Enum.any?(campaign_criteria, &(&1.criterion_id == criterion1.id))
      assert Enum.any?(campaign_criteria, &(&1.criterion_id == criterion2.id))
    end

    test "returns empty list when campaign has no criteria" do
      campaign = Factory.insert(:campaign)

      assert Criteria.list_campaign_criteria(campaign.id) == []
    end
  end

  describe "associate_criterion_to_campaign_by_tenant/2" do
    test "returns error when campaign does not exist for tenant" do
      criterion = Factory.insert(:criterion, tenant: "tenant-123")

      attrs = %{
        "campaign_id" => Uniq.UUID.uuid7(),
        "criterion_id" => criterion.id,
        "reward_points_amount" => 100,
        "status" => "active"
      }

      assert {:error, :not_found} =
               Criteria.associate_criterion_to_campaign_by_tenant(attrs, "tenant-123")
    end
  end

  describe "update_campaign_criterion_by_tenant/4" do
    test "returns error when campaign criterion does not exist for tenant" do
      campaign = Factory.insert(:campaign, tenant: "tenant-123")
      criterion = Factory.insert(:criterion, tenant: "tenant-123")

      assert {:error, :not_found} =
               Criteria.update_campaign_criterion_by_tenant(
                 campaign.id,
                 criterion.id,
                 %{},
                 "tenant-123"
               )
    end
  end

  describe "remove_campaign_criterion_by_tenant/3" do
    test "returns error when campaign criterion does not exist for tenant" do
      campaign = Factory.insert(:campaign, tenant: "tenant-123")
      criterion = Factory.insert(:criterion, tenant: "tenant-123")

      assert {:error, :not_found} =
               Criteria.remove_campaign_criterion_by_tenant(
                 campaign.id,
                 criterion.id,
                 "tenant-123"
               )
    end
  end
end
