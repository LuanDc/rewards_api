defmodule CampaignsApi.ParticipantManagementTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import CampaignsApi.Factory
  import Ecto.Query

  alias CampaignsApi.ParticipantManagement
  alias CampaignsApi.Repo

  describe "create_participant/2" do
    test "creates participant with valid attributes" do
      tenant = insert(:tenant)
      attrs = params_for(:participant, name: "John Doe", nickname: "johndoe")

      assert {:ok, participant} = ParticipantManagement.create_participant(tenant.id, attrs)
      assert participant.name == "John Doe"
      assert participant.nickname == "johndoe"
      assert participant.tenant_id == tenant.id
      assert participant.status == :active
    end

    test "returns error with invalid attributes" do
      tenant = insert(:tenant)
      attrs = %{name: "", nickname: "ab"}

      assert {:error, changeset} = ParticipantManagement.create_participant(tenant.id, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns error when nickname is not unique" do
      tenant = insert(:tenant)
      _existing_participant = insert(:participant, tenant: tenant, nickname: "johndoe")

      attrs = params_for(:participant, nickname: "johndoe")

      assert {:error, changeset} = ParticipantManagement.create_participant(tenant.id, attrs)
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_participant/2" do
    test "returns participant when it exists and belongs to tenant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      assert found = ParticipantManagement.get_participant(tenant.id, participant.id)
      assert found.id == participant.id
      assert found.tenant_id == tenant.id
    end

    test "returns nil when participant does not exist" do
      tenant = insert(:tenant)
      non_existent_id = Ecto.UUID.generate()

      assert nil == ParticipantManagement.get_participant(tenant.id, non_existent_id)
    end

    test "returns nil when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)

      assert nil == ParticipantManagement.get_participant(tenant_b.id, participant.id)
    end
  end

  describe "update_participant/3" do
    test "updates participant with valid attributes" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant, name: "John Doe", nickname: "johndoe")

      attrs = %{name: "Jane Doe", nickname: "janedoe"}

      assert {:ok, updated} = ParticipantManagement.update_participant(tenant.id, participant.id, attrs)
      assert updated.id == participant.id
      assert updated.name == "Jane Doe"
      assert updated.nickname == "janedoe"
      assert updated.tenant_id == tenant.id
    end

    test "returns error with invalid attributes" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      attrs = %{name: "", nickname: "ab"}

      assert {:error, changeset} = ParticipantManagement.update_participant(tenant.id, participant.id, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns error when participant does not exist" do
      tenant = insert(:tenant)
      non_existent_id = Ecto.UUID.generate()

      attrs = %{name: "Jane Doe"}

      assert {:error, :not_found} = ParticipantManagement.update_participant(tenant.id, non_existent_id, attrs)
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)

      attrs = %{name: "Jane Doe"}

      assert {:error, :not_found} = ParticipantManagement.update_participant(tenant_b.id, participant.id, attrs)
    end

    test "returns error when nickname is not unique" do
      tenant = insert(:tenant)
      _existing_participant = insert(:participant, tenant: tenant, nickname: "johndoe")
      participant = insert(:participant, tenant: tenant, nickname: "janedoe")

      attrs = %{nickname: "johndoe"}

      assert {:error, changeset} = ParticipantManagement.update_participant(tenant.id, participant.id, attrs)
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "delete_participant/2" do
    test "deletes participant when it exists and belongs to tenant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      assert {:ok, deleted} = ParticipantManagement.delete_participant(tenant.id, participant.id)
      assert deleted.id == participant.id

      # Verify participant is actually deleted
      assert nil == ParticipantManagement.get_participant(tenant.id, participant.id)
    end

    test "returns error when participant does not exist" do
      tenant = insert(:tenant)
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ParticipantManagement.delete_participant(tenant.id, non_existent_id)
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)

      assert {:error, :not_found} = ParticipantManagement.delete_participant(tenant_b.id, participant.id)

      # Verify participant still exists for tenant_a
      assert ParticipantManagement.get_participant(tenant_a.id, participant.id)
    end
  end

  describe "list_participants/2" do
    test "lists participants without cursor" do
      tenant = insert(:tenant)
      participant1 = insert(:participant, tenant: tenant, name: "Alice", nickname: "alice")
      participant2 = insert(:participant, tenant: tenant, name: "Bob", nickname: "bob")
      participant3 = insert(:participant, tenant: tenant, name: "Charlie", nickname: "charlie")

      result = ParticipantManagement.list_participants(tenant.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      # Verify ordering by inserted_at descending (newest first)
      participant_ids = Enum.map(data, & &1.id)
      assert participant3.id in participant_ids
      assert participant2.id in participant_ids
      assert participant1.id in participant_ids
    end

    test "lists participants with cursor" do
      tenant = insert(:tenant)

      # Insert multiple participants
      insert_list(12, :participant, tenant: tenant)

      # Get first page
      first_page = ParticipantManagement.list_participants(tenant.id, limit: 5)
      assert length(first_page.data) == 5

      # If there are more results, test cursor pagination
      if first_page.has_more do
        assert first_page.next_cursor != nil

        # Get second page using cursor
        second_page = ParticipantManagement.list_participants(tenant.id, limit: 5, cursor: first_page.next_cursor)

        # Verify no duplicates between pages
        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain participants from first page"
      end
    end

    test "enforces maximum limit of 100" do
      tenant = insert(:tenant)

      # Insert 10 participants
      for i <- 1..10 do
        insert(:participant, tenant: tenant, nickname: "user#{i}")
      end

      # Request with limit > 100
      result = ParticipantManagement.list_participants(tenant.id, limit: 150)

      # Should return at most 100 (but we only have 10)
      assert %{data: data} = result
      assert length(data) == 10
    end

    test "filters by nickname (case-insensitive)" do
      tenant = insert(:tenant)
      insert(:participant, tenant: tenant, nickname: "alice123")
      insert(:participant, tenant: tenant, nickname: "bob456")
      insert(:participant, tenant: tenant, nickname: "ALICE789")
      insert(:participant, tenant: tenant, nickname: "charlie")

      result = ParticipantManagement.list_participants(tenant.id, nickname: "alice")

      assert %{data: data} = result
      assert length(data) == 2
      assert Enum.all?(data, fn p -> String.contains?(String.downcase(p.nickname), "alice") end)
    end

    test "returns correct pagination response structure" do
      tenant = insert(:tenant)
      insert(:participant, tenant: tenant)

      result = ParticipantManagement.list_participants(tenant.id, [])

      assert %{data: data, next_cursor: next_cursor, has_more: has_more} = result
      assert is_list(data)
      assert is_boolean(has_more)
      assert next_cursor == nil or match?(%DateTime{}, next_cursor)
    end

    test "returns empty results for tenant with no participants" do
      tenant = insert(:tenant)

      result = ParticipantManagement.list_participants(tenant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "only returns participants for requesting tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)

      participant_a = insert(:participant, tenant: tenant_a, nickname: "tenant_a_user")
      _participant_b = insert(:participant, tenant: tenant_b, nickname: "tenant_b_user")

      result = ParticipantManagement.list_participants(tenant_a.id, [])

      assert %{data: data} = result
      assert length(data) == 1
      assert hd(data).id == participant_a.id
      assert hd(data).tenant_id == tenant_a.id
    end
  end

  describe "CRUD round trip" do
    test "create → read → update → read → delete maintains data integrity" do
      tenant = insert(:tenant)

      # Create
      create_attrs = params_for(:participant, name: "John Doe", nickname: "johndoe")
      assert {:ok, participant} = ParticipantManagement.create_participant(tenant.id, create_attrs)
      assert participant.name == "John Doe"
      assert participant.nickname == "johndoe"
      assert participant.status == :active
      participant_id = participant.id

      # Read
      assert found = ParticipantManagement.get_participant(tenant.id, participant_id)
      assert found.id == participant_id
      assert found.name == "John Doe"
      assert found.nickname == "johndoe"

      # Update
      update_attrs = %{name: "Jane Doe", nickname: "janedoe"}
      assert {:ok, updated} = ParticipantManagement.update_participant(tenant.id, participant_id, update_attrs)
      assert updated.id == participant_id
      assert updated.name == "Jane Doe"
      assert updated.nickname == "janedoe"

      # Read again
      assert found_updated = ParticipantManagement.get_participant(tenant.id, participant_id)
      assert found_updated.id == participant_id
      assert found_updated.name == "Jane Doe"
      assert found_updated.nickname == "janedoe"

      # Delete
      assert {:ok, deleted} = ParticipantManagement.delete_participant(tenant.id, participant_id)
      assert deleted.id == participant_id

      # Verify deletion
      assert nil == ParticipantManagement.get_participant(tenant.id, participant_id)
    end
  end

  describe "associate_participant_with_campaign/3" do
    test "associates participant with campaign in same tenant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      assert {:ok, campaign_participant} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      assert campaign_participant.participant_id == participant.id
      assert campaign_participant.campaign_id == campaign.id
    end

    test "returns error when associating cross-tenant resources" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_b)

      assert {:error, :tenant_mismatch} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant_a.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_b)

      # Try to associate using tenant_b (campaign's tenant)
      assert {:error, :tenant_mismatch} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant_b.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when campaign belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_b)

      # Try to associate using tenant_a (participant's tenant)
      assert {:error, :tenant_mismatch} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant_a.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error for duplicate association" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Create first association
      assert {:ok, _} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      # Try to create duplicate association
      assert {:error, changeset} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "disassociate_participant_from_campaign/3" do
    test "disassociates participant from campaign" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Create association
      {:ok, campaign_participant} =
        ParticipantManagement.associate_participant_with_campaign(
          tenant.id,
          participant.id,
          campaign.id
        )

      # Disassociate
      assert {:ok, deleted} =
               ParticipantManagement.disassociate_participant_from_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      assert deleted.id == campaign_participant.id

      # Verify association is removed by trying to create it again (should succeed)
      assert {:ok, _new_association} =
               ParticipantManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when association does not exist" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Try to disassociate without creating association first
      assert {:error, :not_found} =
               ParticipantManagement.disassociate_participant_from_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when trying to disassociate cross-tenant resources" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)

      # Create association in tenant_a
      {:ok, _} =
        ParticipantManagement.associate_participant_with_campaign(
          tenant_a.id,
          participant.id,
          campaign.id
        )

      # Try to disassociate using tenant_b
      assert {:error, :not_found} =
               ParticipantManagement.disassociate_participant_from_campaign(
                 tenant_b.id,
                 participant.id,
                 campaign.id
               )
    end
  end

  describe "list_campaigns_for_participant/3" do
    test "lists campaigns for participant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign1 = insert(:campaign, tenant: tenant, name: "Campaign 1")
      campaign2 = insert(:campaign, tenant: tenant, name: "Campaign 2")
      campaign3 = insert(:campaign, tenant: tenant, name: "Campaign 3")

      # Associate participant with campaigns
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign1.id)
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign2.id)
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign3.id)

      result = ParticipantManagement.list_campaigns_for_participant(tenant.id, participant.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      campaign_ids = Enum.map(data, & &1.id)
      assert campaign1.id in campaign_ids
      assert campaign2.id in campaign_ids
      assert campaign3.id in campaign_ids
    end

    test "returns empty list when participant has no campaigns" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      result = ParticipantManagement.list_campaigns_for_participant(tenant.id, participant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "returns empty list for cross-tenant participant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)

      # Associate in tenant_a
      ParticipantManagement.associate_participant_with_campaign(tenant_a.id, participant.id, campaign.id)

      # Try to list using tenant_b
      result = ParticipantManagement.list_campaigns_for_participant(tenant_b.id, participant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "supports pagination" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      # Create and associate 3 campaigns with delays to ensure different timestamps
      campaign1 = insert(:campaign, tenant: tenant, name: "Campaign 1")
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign1.id)

      # Sleep 1 second to ensure different timestamp
      Process.sleep(1100)

      campaign2 = insert(:campaign, tenant: tenant, name: "Campaign 2")
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign2.id)

      Process.sleep(1100)

      campaign3 = insert(:campaign, tenant: tenant, name: "Campaign 3")
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign3.id)

      # Get first page with limit 2
      first_page = ParticipantManagement.list_campaigns_for_participant(tenant.id, participant.id, limit: 2)

      assert length(first_page.data) == 2
      assert first_page.has_more == true
      assert first_page.next_cursor != nil

      # Get second page
      second_page =
        ParticipantManagement.list_campaigns_for_participant(
          tenant.id,
          participant.id,
          limit: 2,
          cursor: first_page.next_cursor
        )

      assert length(second_page.data) == 1
      assert second_page.has_more == false

      # Verify no duplicates
      first_page_ids = Enum.map(first_page.data, & &1.id)
      second_page_ids = Enum.map(second_page.data, & &1.id)
      assert Enum.all?(second_page_ids, &(&1 not in first_page_ids))
    end
  end

  describe "list_participants_for_campaign/3" do
    test "lists participants for campaign" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      participant1 = insert(:participant, tenant: tenant, nickname: "user1")
      participant2 = insert(:participant, tenant: tenant, nickname: "user2")
      participant3 = insert(:participant, tenant: tenant, nickname: "user3")

      # Associate participants with campaign
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant1.id, campaign.id)
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant2.id, campaign.id)
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant3.id, campaign.id)

      result = ParticipantManagement.list_participants_for_campaign(tenant.id, campaign.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      participant_ids = Enum.map(data, & &1.id)
      assert participant1.id in participant_ids
      assert participant2.id in participant_ids
      assert participant3.id in participant_ids
    end

    test "returns empty list when campaign has no participants" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      result = ParticipantManagement.list_participants_for_campaign(tenant.id, campaign.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "returns empty list for cross-tenant campaign" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)

      # Associate in tenant_a
      ParticipantManagement.associate_participant_with_campaign(tenant_a.id, participant.id, campaign.id)

      # Try to list using tenant_b
      result = ParticipantManagement.list_participants_for_campaign(tenant_b.id, campaign.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "supports pagination" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Create and associate 3 participants with delays to ensure different timestamps
      participant1 = insert(:participant, tenant: tenant, nickname: "user1")
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant1.id, campaign.id)

      # Sleep 1 second to ensure different timestamp
      Process.sleep(1100)

      participant2 = insert(:participant, tenant: tenant, nickname: "user2")
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant2.id, campaign.id)

      Process.sleep(1100)

      participant3 = insert(:participant, tenant: tenant, nickname: "user3")
      ParticipantManagement.associate_participant_with_campaign(tenant.id, participant3.id, campaign.id)

      # Get first page with limit 2
      first_page = ParticipantManagement.list_participants_for_campaign(tenant.id, campaign.id, limit: 2)

      assert length(first_page.data) == 2
      assert first_page.has_more == true
      assert first_page.next_cursor != nil

      # Get second page
      second_page =
        ParticipantManagement.list_participants_for_campaign(
          tenant.id,
          campaign.id,
          limit: 2,
          cursor: first_page.next_cursor
        )

      assert length(second_page.data) == 1
      assert second_page.has_more == false

      # Verify no duplicates
      first_page_ids = Enum.map(first_page.data, & &1.id)
      second_page_ids = Enum.map(second_page.data, & &1.id)
      assert Enum.all?(second_page_ids, &(&1 not in first_page_ids))
    end
  end

  describe "property-based tests" do
    # **Validates: Requirements 3.4, 11.1-11.8**
    property "tenant isolation: cross-tenant access always fails" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15) do

        # Create two different tenants with unique IDs
        tenant_a = insert(:tenant)
        tenant_b = insert(:tenant)

        # Create participant for tenant A with unique nickname
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = ParticipantManagement.create_participant(tenant_a.id, attrs)

        # Tenant B should never see Tenant A's participant
        assert nil == ParticipantManagement.get_participant(tenant_b.id, participant.id)

        # Tenant B should not be able to update Tenant A's participant
        update_attrs = %{name: "Updated Name"}
        assert {:error, :not_found} == ParticipantManagement.update_participant(tenant_b.id, participant.id, update_attrs)

        # Tenant B should not be able to delete Tenant A's participant
        assert {:error, :not_found} == ParticipantManagement.delete_participant(tenant_b.id, participant.id)

        # Verify participant still exists for Tenant A
        assert ParticipantManagement.get_participant(tenant_a.id, participant.id)
      end
    end

    # **Validates: Requirements 3.8, 5.4**
    property "cascade deletion: all associations removed when participant is deleted" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
                num_campaigns <- integer(1..3),
                num_challenges_per_campaign <- integer(1..2) do

        # Create tenant and participant with unique nickname
        tenant = insert(:tenant)
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = ParticipantManagement.create_participant(tenant.id, attrs)

        # Create campaigns and manually insert campaign_participants associations
        campaigns = for _ <- 1..num_campaigns do
          campaign = insert(:campaign, tenant: tenant)

          # Manually insert campaign_participant association
          %CampaignsApi.ParticipantManagement.CampaignParticipant{}
          |> Ecto.Changeset.change(%{
            participant_id: participant.id,
            campaign_id: campaign.id
          })
          |> Repo.insert!()

          campaign
        end

        # Create challenges and manually insert participant_challenges associations
        for campaign <- campaigns do
          for _ <- 1..num_challenges_per_campaign do
            challenge = insert(:challenge)

            # Manually insert participant_challenge association
            %CampaignsApi.ParticipantManagement.ParticipantChallenge{}
            |> Ecto.Changeset.change(%{
              participant_id: participant.id,
              challenge_id: challenge.id,
              campaign_id: campaign.id
            })
            |> Repo.insert!()
          end
        end

        # Verify associations exist
        campaign_associations = Repo.all(
          from cp in CampaignsApi.ParticipantManagement.CampaignParticipant,
          where: cp.participant_id == ^participant.id
        )
        assert length(campaign_associations) == num_campaigns

        challenge_associations = Repo.all(
          from pc in CampaignsApi.ParticipantManagement.ParticipantChallenge,
          where: pc.participant_id == ^participant.id
        )
        assert length(challenge_associations) == num_campaigns * num_challenges_per_campaign

        # Delete participant
        assert {:ok, _deleted} = ParticipantManagement.delete_participant(tenant.id, participant.id)

        # Verify participant is deleted
        assert nil == ParticipantManagement.get_participant(tenant.id, participant.id)

        # Verify all campaign associations are deleted (cascade)
        remaining_campaign_associations = Repo.all(
          from cp in CampaignsApi.ParticipantManagement.CampaignParticipant,
          where: cp.participant_id == ^participant.id
        )
        assert Enum.empty?(remaining_campaign_associations)

        # Verify all challenge associations are deleted (cascade)
        remaining_challenge_associations = Repo.all(
          from pc in CampaignsApi.ParticipantManagement.ParticipantChallenge,
          where: pc.participant_id == ^participant.id
        )
        assert Enum.empty?(remaining_challenge_associations)
      end
    end

    # **Validates: Requirements 2.6, 5.1, 5.2, 9.6, 11.5**
    property "campaign-participant tenant validation: only same-tenant associations succeed" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
                campaign_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                same_tenant <- boolean() do

        # Create two tenants
        tenant_a = insert(:tenant)
        tenant_b = insert(:tenant)

        # Create participant in tenant_a with unique nickname
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        participant_attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = ParticipantManagement.create_participant(tenant_a.id, participant_attrs)

        # Create campaign in either same tenant or different tenant
        campaign_tenant = if same_tenant, do: tenant_a, else: tenant_b
        campaign = insert(:campaign, tenant: campaign_tenant, name: campaign_name)

        # Attempt to associate
        result =
          ParticipantManagement.associate_participant_with_campaign(
            tenant_a.id,
            participant.id,
            campaign.id
          )

        if same_tenant do
          # Same tenant: association should succeed
          assert {:ok, campaign_participant} = result
          assert campaign_participant.participant_id == participant.id
          assert campaign_participant.campaign_id == campaign.id

          # Verify association exists in database
          assert Repo.get_by(CampaignsApi.ParticipantManagement.CampaignParticipant,
                   participant_id: participant.id,
                   campaign_id: campaign.id
                 )
        else
          # Different tenants: association should fail
          assert {:error, :tenant_mismatch} = result

          # Verify no association was created
          refute Repo.get_by(CampaignsApi.ParticipantManagement.CampaignParticipant,
                   participant_id: participant.id,
                   campaign_id: campaign.id
                 )
        end
      end
    end
  end

  describe "associate_participant_with_challenge/3" do
    test "associates participant with challenge when participant is in campaign" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Associate participant with campaign first
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Now associate participant with challenge
      assert {:ok, participant_challenge} =
               ParticipantManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      assert participant_challenge.participant_id == participant.id
      assert participant_challenge.challenge_id == challenge.id
      assert participant_challenge.campaign_id == campaign.id
    end

    test "returns error when participant is not in campaign" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Associate challenge with campaign but NOT participant with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Attempt to associate participant with challenge
      assert {:error, :participant_not_in_campaign} =
               ParticipantManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when challenge belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign_a = insert(:campaign, tenant: tenant_a)
      campaign_b = insert(:campaign, tenant: tenant_b)
      challenge = insert(:challenge)

      # Associate participant with campaign_a
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign_a.id
      )

      # Associate challenge with campaign_b (different tenant)
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign_b, challenge: challenge)

      # Attempt to associate participant with challenge
      assert {:error, :tenant_mismatch} =
               ParticipantManagement.associate_participant_with_challenge(
                 tenant_a.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_b)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Attempt to associate participant with challenge using tenant_a
      assert {:error, :tenant_mismatch} =
               ParticipantManagement.associate_participant_with_challenge(
                 tenant_a.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error on duplicate association" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Associate participant with campaign
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # First association should succeed
      assert {:ok, _pc} =
               ParticipantManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      # Second association should fail
      assert {:error, changeset} =
               ParticipantManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "disassociate_participant_from_challenge/3" do
    test "disassociates participant from challenge" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Set up associations
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, participant_challenge} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge.id
        )

      # Disassociate
      assert {:ok, deleted} =
               ParticipantManagement.disassociate_participant_from_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      assert deleted.id == participant_challenge.id

      # Verify association is deleted
      refute Repo.get(CampaignsApi.ParticipantManagement.ParticipantChallenge, participant_challenge.id)
    end

    test "returns error when association does not exist" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      challenge = insert(:challenge)

      assert {:error, :not_found} =
               ParticipantManagement.disassociate_participant_from_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when association belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Set up associations in tenant_a
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign.id
      )
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant_a.id,
          participant.id,
          challenge.id
        )

      # Attempt to disassociate using tenant_b
      assert {:error, :not_found} =
               ParticipantManagement.disassociate_participant_from_challenge(
                 tenant_b.id,
                 participant.id,
                 challenge.id
               )
    end
  end

  describe "list_challenges_for_participant/3" do
    test "lists challenges for participant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge, name: "Challenge 1")
      challenge2 = insert(:challenge, name: "Challenge 2")

      # Set up associations
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )
      _cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      _cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)
      {:ok, _pc1} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge1.id
        )
      {:ok, _pc2} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge2.id
        )

      # List challenges
      result = ParticipantManagement.list_challenges_for_participant(tenant.id, participant.id)

      assert %{data: challenges, has_more: false} = result
      assert length(challenges) == 2
      challenge_ids = Enum.map(challenges, & &1.id)
      assert challenge1.id in challenge_ids
      assert challenge2.id in challenge_ids
    end

    test "filters challenges by campaign_id" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign1 = insert(:campaign, tenant: tenant, name: "Campaign 1")
      campaign2 = insert(:campaign, tenant: tenant, name: "Campaign 2")
      challenge1 = insert(:challenge, name: "Challenge 1")
      challenge2 = insert(:challenge, name: "Challenge 2")

      # Associate participant with both campaigns
      {:ok, _cp1} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign1.id
      )
      {:ok, _cp2} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign2.id
      )

      # Associate challenges with campaigns
      _cc1 = insert(:campaign_challenge, campaign: campaign1, challenge: challenge1)
      _cc2 = insert(:campaign_challenge, campaign: campaign2, challenge: challenge2)

      # Associate participant with both challenges
      {:ok, _pc1} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge1.id
        )
      {:ok, _pc2} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge2.id
        )

      # List challenges filtered by campaign1
      result = ParticipantManagement.list_challenges_for_participant(
        tenant.id,
        participant.id,
        campaign_id: campaign1.id
      )

      assert %{data: challenges, has_more: false} = result
      assert length(challenges) == 1
      assert hd(challenges).id == challenge1.id
    end

    test "returns empty list for participant with no challenges" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      result = ParticipantManagement.list_challenges_for_participant(tenant.id, participant.id)

      assert %{data: [], has_more: false} = result
    end

    test "returns empty list for different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Set up associations in tenant_a
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign.id
      )
      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant_a.id,
          participant.id,
          challenge.id
        )

      # Query with tenant_b
      result = ParticipantManagement.list_challenges_for_participant(tenant_b.id, participant.id)

      assert %{data: [], has_more: false} = result
    end
  end

  describe "list_participants_for_challenge/3" do
    test "lists participants for challenge" do
      tenant = insert(:tenant)
      participant1 = insert(:participant, tenant: tenant, nickname: "user1")
      participant2 = insert(:participant, tenant: tenant, nickname: "user2")
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Set up associations
      {:ok, _cp1} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant1.id,
        campaign.id
      )
      {:ok, _cp2} = ParticipantManagement.associate_participant_with_campaign(
        tenant.id,
        participant2.id,
        campaign.id
      )
      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc1} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant1.id,
          challenge.id
        )
      {:ok, _pc2} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant.id,
          participant2.id,
          challenge.id
        )

      # List participants
      result = ParticipantManagement.list_participants_for_challenge(tenant.id, challenge.id)

      assert %{data: participants, has_more: false} = result
      assert length(participants) == 2
      participant_ids = Enum.map(participants, & &1.id)
      assert participant1.id in participant_ids
      assert participant2.id in participant_ids
    end

    test "returns empty list for challenge with no participants" do
      tenant = insert(:tenant)
      challenge = insert(:challenge)

      result = ParticipantManagement.list_participants_for_challenge(tenant.id, challenge.id)

      assert %{data: [], has_more: false} = result
    end

    test "returns empty list for different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Set up associations in tenant_a
      {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign.id
      )
      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc} =
        ParticipantManagement.associate_participant_with_challenge(
          tenant_a.id,
          participant.id,
          challenge.id
        )

      # Query with tenant_b
      result = ParticipantManagement.list_participants_for_challenge(tenant_b.id, challenge.id)

      assert %{data: [], has_more: false} = result
    end
  end

  describe "challenge associations - property tests" do
    # **Validates: Requirements 2.1.7, 2.1.8, 2.1.9, 5.1.1-5.1.4**
    property "participant-challenge campaign membership: only campaign members can be assigned to challenges" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
                is_campaign_member <- boolean() do

        # Create tenant, participant, campaign, and challenge
        tenant = insert(:tenant)
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        participant_attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = ParticipantManagement.create_participant(tenant.id, participant_attrs)

        campaign = insert(:campaign, tenant: tenant)
        challenge = insert(:challenge)
        _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

        # Conditionally associate participant with campaign
        if is_campaign_member do
          {:ok, _cp} = ParticipantManagement.associate_participant_with_campaign(
            tenant.id,
            participant.id,
            campaign.id
          )
        end

        # Attempt to associate participant with challenge
        result =
          ParticipantManagement.associate_participant_with_challenge(
            tenant.id,
            participant.id,
            challenge.id
          )

        if is_campaign_member do
          # Campaign member: association should succeed
          assert {:ok, participant_challenge} = result
          assert participant_challenge.participant_id == participant.id
          assert participant_challenge.challenge_id == challenge.id
          assert participant_challenge.campaign_id == campaign.id

          # Verify association exists in database
          assert Repo.get_by(CampaignsApi.ParticipantManagement.ParticipantChallenge,
                   participant_id: participant.id,
                   challenge_id: challenge.id
                 )
        else
          # Not a campaign member: association should fail
          assert {:error, :participant_not_in_campaign} = result

          # Verify no association was created
          refute Repo.get_by(CampaignsApi.ParticipantManagement.ParticipantChallenge,
                   participant_id: participant.id,
                   challenge_id: challenge.id
                 )
        end
      end
    end
  end
end
