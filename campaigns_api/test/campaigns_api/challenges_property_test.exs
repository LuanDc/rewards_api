defmodule CampaignsApi.ChallengesPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import Ecto.Query

  alias CampaignsApi.Challenges
  alias CampaignsApi.Challenges.Challenge
  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants

  setup do
    {:ok, tenant1} = Tenants.create_tenant("test-tenant-1-#{System.unique_integer([:positive])}")
    {:ok, tenant2} = Tenants.create_tenant("test-tenant-2-#{System.unique_integer([:positive])}")

    {:ok, tenant1: tenant1, tenant2: tenant2}
  end

  property "Property 1: Challenge Global Availability - any challenge created is retrievable and usable by any tenant",
           %{tenant1: tenant1, tenant2: tenant2} do
    check all(
            name <- challenge_name_generator(),
            max_runs: 100
          ) do
      # Create a challenge (no tenant association)
      {:ok, challenge} = Challenges.create_challenge(%{name: name})

      # Both tenants can retrieve the same challenge
      retrieved_by_tenant1 = Challenges.get_challenge(challenge.id)
      retrieved_by_tenant2 = Challenges.get_challenge(challenge.id)

      assert retrieved_by_tenant1 != nil,
             "tenant1 should be able to retrieve the challenge"

      assert retrieved_by_tenant2 != nil,
             "tenant2 should be able to retrieve the challenge"

      assert retrieved_by_tenant1.id == challenge.id,
             "tenant1 should retrieve the correct challenge"

      assert retrieved_by_tenant2.id == challenge.id,
             "tenant2 should retrieve the correct challenge"

      assert retrieved_by_tenant1.id == retrieved_by_tenant2.id,
             "both tenants should retrieve the same challenge"

      # Both tenants can use the challenge in their campaigns
      campaign1 = insert(:campaign, tenant: tenant1)
      campaign2 = insert(:campaign, tenant: tenant2)

      {:ok, cc1} =
        insert(:campaign_challenge, campaign: campaign1, challenge: challenge)
        |> then(&{:ok, &1})

      {:ok, cc2} =
        insert(:campaign_challenge, campaign: campaign2, challenge: challenge)
        |> then(&{:ok, &1})

      assert cc1.challenge_id == challenge.id,
             "tenant1 should be able to associate the challenge with their campaign"

      assert cc2.challenge_id == challenge.id,
             "tenant2 should be able to associate the challenge with their campaign"

      # Verify the challenge still exists and is accessible
      final_check = Challenges.get_challenge(challenge.id)

      assert final_check != nil,
             "challenge should still be accessible after being used by multiple tenants"
    end
  end

  property "Property 6: Challenge Deletion Protection - any challenge with campaign associations cannot be deleted",
           %{tenant1: tenant1, tenant2: tenant2} do
    check all(
            name <- challenge_name_generator(),
            association_count <- integer(1..5),
            max_runs: 100
          ) do
      # Create a challenge
      {:ok, challenge} = Challenges.create_challenge(%{name: name})

      # Create multiple campaign associations from different tenants
      _associations =
        Enum.map(1..association_count, fn i ->
          tenant = if rem(i, 2) == 0, do: tenant1, else: tenant2
          campaign = insert(:campaign, tenant: tenant)
          insert(:campaign_challenge, campaign: campaign, challenge: challenge)
        end)

      # Attempt to delete the challenge should fail
      result = Challenges.delete_challenge(challenge.id)

      assert result == {:error, :has_associations},
             "challenge with #{association_count} associations should not be deletable"

      # Verify challenge still exists
      assert Challenges.get_challenge(challenge.id) != nil,
             "challenge should still exist after failed deletion attempt"

      # Verify all associations still exist
      association_count_in_db =
        Repo.one(
          from cc in CampaignsApi.CampaignManagement.CampaignChallenge,
            where: cc.challenge_id == ^challenge.id,
            select: count(cc.id)
        )

      assert association_count_in_db == association_count,
             "all campaign associations should still exist"

      # Remove all associations
      Repo.delete_all(
        from cc in CampaignsApi.CampaignManagement.CampaignChallenge,
          where: cc.challenge_id == ^challenge.id
      )

      # Now deletion should succeed
      {:ok, deleted_challenge} = Challenges.delete_challenge(challenge.id)

      assert deleted_challenge.id == challenge.id,
             "challenge should be deletable after removing all associations"

      # Verify challenge no longer exists
      assert Challenges.get_challenge(challenge.id) == nil,
             "challenge should not exist after successful deletion"
    end
  end

  property "any challenge created has valid UUID and is persisted in database" do
    check all(
            name <- challenge_name_generator(),
            max_runs: 100
          ) do
      {:ok, challenge} = Challenges.create_challenge(%{name: name})

      assert is_binary(challenge.id), "challenge id should be a binary (UUID)"
      assert String.length(challenge.id) == 36, "challenge id should be a valid UUID format"

      assert challenge.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
             "challenge id should match UUID format"

      db_challenge = Repo.get(Challenge, challenge.id)
      assert db_challenge != nil, "challenge should be persisted in database"
      assert db_challenge.name == name, "persisted challenge should have correct name"
    end
  end

  property "challenges are valid with or without optional fields (description, metadata)" do
    check all(
            name <- challenge_name_generator(),
            include_description <- boolean(),
            include_metadata <- boolean(),
            description <- string(:alphanumeric, min_length: 1, max_length: 100),
            metadata <- json_metadata_generator(),
            max_runs: 100
          ) do
      attrs = %{name: name}

      attrs =
        if include_description do
          Map.put(attrs, :description, description)
        else
          attrs
        end

      attrs =
        if include_metadata do
          Map.put(attrs, :metadata, metadata)
        else
          attrs
        end

      {:ok, challenge} = Challenges.create_challenge(attrs)

      assert challenge.name == name, "challenge should have the provided name"

      if include_description do
        assert challenge.description == description
      else
        assert challenge.description == nil
      end

      if include_metadata do
        assert challenge.metadata == metadata
      else
        assert challenge.metadata == nil
      end
    end
  end

  property "any challenge list is ordered by inserted_at descending (most recent first)" do
    check all(
            challenge_count <- integer(2..10),
            max_runs: 100
          ) do
      Repo.delete_all(Challenge)

      _challenges =
        Enum.map(1..challenge_count, fn i ->
          {:ok, challenge} = Challenges.create_challenge(%{name: "Challenge #{i}"})
          challenge
        end)

      result = Challenges.list_challenges()

      returned_challenges = result.data
      assert length(returned_challenges) == challenge_count

      if length(returned_challenges) > 1 do
        returned_challenges
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [current, next] ->
          comparison = DateTime.compare(current.inserted_at, next.inserted_at)

          assert comparison in [:gt, :eq],
                 "challenges should be ordered by inserted_at descending (most recent first)"
        end)
      end
    end
  end

  property "any challenge retrieved or created includes all required fields" do
    check all(
            name <- challenge_name_generator(),
            max_runs: 100
          ) do
      {:ok, created_challenge} = Challenges.create_challenge(%{name: name})

      assert Map.has_key?(created_challenge, :id), "challenge should have :id field"
      assert Map.has_key?(created_challenge, :name), "challenge should have :name field"

      assert Map.has_key?(created_challenge, :description),
             "challenge should have :description field"

      assert Map.has_key?(created_challenge, :metadata),
             "challenge should have :metadata field"

      assert Map.has_key?(created_challenge, :inserted_at),
             "challenge should have :inserted_at field"

      assert Map.has_key?(created_challenge, :updated_at),
             "challenge should have :updated_at field"

      retrieved_challenge = Challenges.get_challenge(created_challenge.id)

      assert Map.has_key?(retrieved_challenge, :id)
      assert Map.has_key?(retrieved_challenge, :name)
      assert Map.has_key?(retrieved_challenge, :description)
      assert Map.has_key?(retrieved_challenge, :metadata)
      assert Map.has_key?(retrieved_challenge, :inserted_at)
      assert Map.has_key?(retrieved_challenge, :updated_at)

      assert retrieved_challenge.id == created_challenge.id
      assert retrieved_challenge.name == created_challenge.name
    end
  end

  property "challenge update allows modifying mutable fields while keeping id immutable" do
    check all(
            original_name <- challenge_name_generator(),
            new_name <- challenge_name_generator(),
            new_description <- string(:alphanumeric, min_length: 1, max_length: 100),
            new_metadata <- json_metadata_generator(),
            max_runs: 100
          ) do
      {:ok, challenge} = Challenges.create_challenge(%{name: original_name})

      original_id = challenge.id

      update_attrs = %{
        name: new_name,
        description: new_description,
        metadata: new_metadata
      }

      {:ok, updated_challenge} = Challenges.update_challenge(challenge.id, update_attrs)

      assert updated_challenge.name == new_name, "name should be mutable"
      assert updated_challenge.description == new_description, "description should be mutable"
      assert updated_challenge.metadata == new_metadata, "metadata should be mutable"

      assert updated_challenge.id == original_id, "id should be immutable"
    end
  end

  property "any deleted challenge without associations cannot be retrieved and does not appear in list queries" do
    check all(
            name <- challenge_name_generator(),
            max_runs: 100
          ) do
      {:ok, challenge} = Challenges.create_challenge(%{name: name})
      challenge_id = challenge.id

      assert Challenges.get_challenge(challenge_id) != nil

      {:ok, _deleted} = Challenges.delete_challenge(challenge_id)

      assert Challenges.get_challenge(challenge_id) == nil,
             "deleted challenge should return nil when retrieved"

      result = Challenges.list_challenges()
      challenge_ids = Enum.map(result.data, & &1.id)

      assert challenge_id not in challenge_ids,
             "deleted challenge should not appear in list queries"

      assert {:error, :not_found} = Challenges.delete_challenge(challenge_id),
             "attempting to delete already deleted challenge should return :not_found"
    end
  end

  property "all challenge datetime fields are stored and retrieved in UTC timezone" do
    check all(
            name <- challenge_name_generator(),
            max_runs: 100
          ) do
      {:ok, challenge} = Challenges.create_challenge(%{name: name})

      assert challenge.inserted_at.time_zone == "Etc/UTC",
             "inserted_at should be stored in UTC timezone"

      assert challenge.updated_at.time_zone == "Etc/UTC",
             "updated_at should be stored in UTC timezone"

      retrieved_challenge = Challenges.get_challenge(challenge.id)
      assert retrieved_challenge.inserted_at.time_zone == "Etc/UTC"
      assert retrieved_challenge.updated_at.time_zone == "Etc/UTC"
    end
  end

  defp challenge_name_generator do
    gen all(
          prefix <-
            member_of([
              "TransactionsChecker",
              "PointsValidator",
              "BehaviorAnalyzer",
              "ActivityMonitor",
              "RewardCalculator"
            ]),
          suffix <- string(:alphanumeric, min_length: 0, max_length: 10)
        ) do
      if suffix == "" do
        prefix
      else
        "#{prefix} #{suffix}"
      end
    end
  end

  defp json_metadata_generator do
    gen all(
          type <- member_of(["evaluation", "validation", "monitoring"]),
          version <- integer(1..10),
          enabled <- boolean()
        ) do
      %{
        "type" => type,
        "version" => version,
        "enabled" => enabled
      }
    end
  end
end
