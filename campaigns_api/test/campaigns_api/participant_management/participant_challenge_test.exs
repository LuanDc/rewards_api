defmodule CampaignsApi.ParticipantManagement.ParticipantChallengeTest do
  use CampaignsApi.DataCase

  import CampaignsApi.Factory

  alias CampaignsApi.ParticipantManagement.Participant
  alias CampaignsApi.ParticipantManagement.ParticipantChallenge

  describe "changeset/2 - valid association creation" do
    setup do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Create campaign-challenge association
      campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      participant =
        %Participant{}
        |> Participant.changeset(%{
          tenant_id: tenant.id,
          name: "John Doe",
          nickname: "johndoe"
        })
        |> Repo.insert!()

      %{
        tenant: tenant,
        campaign: campaign,
        challenge: challenge,
        campaign_challenge: campaign_challenge,
        participant: participant
      }
    end

    test "creates valid participant-challenge association", %{
      campaign: campaign,
      challenge: challenge,
      participant: participant
    } do
      attrs = %{
        participant_id: participant.id,
        challenge_id: challenge.id,
        campaign_id: campaign.id
      }

      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :participant_id) == participant.id
      assert get_change(changeset, :challenge_id) == challenge.id
      assert get_change(changeset, :campaign_id) == campaign.id
    end

    test "successfully inserts participant-challenge association", %{
      campaign: campaign,
      challenge: challenge,
      participant: participant
    } do
      attrs = %{
        participant_id: participant.id,
        challenge_id: challenge.id,
        campaign_id: campaign.id
      }

      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      assert {:ok, participant_challenge} = Repo.insert(changeset)
      assert participant_challenge.participant_id == participant.id
      assert participant_challenge.challenge_id == challenge.id
      assert participant_challenge.campaign_id == campaign.id
      assert participant_challenge.id != nil
      assert participant_challenge.inserted_at != nil
      assert participant_challenge.updated_at != nil
    end
  end

  describe "changeset/2 - required field validations" do
    test "valid changeset with all required fields" do
      attrs = %{
        participant_id: Ecto.UUID.generate(),
        challenge_id: Ecto.UUID.generate(),
        campaign_id: Ecto.UUID.generate()
      }

      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      assert changeset.valid?
      assert changeset.changes.participant_id == attrs.participant_id
      assert changeset.changes.challenge_id == attrs.challenge_id
      assert changeset.changes.campaign_id == attrs.campaign_id
    end

    test "invalid changeset when participant_id is missing" do
      attrs = %{
        challenge_id: Ecto.UUID.generate(),
        campaign_id: Ecto.UUID.generate()
      }

      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).participant_id
    end

    test "invalid changeset when challenge_id is missing" do
      attrs = %{
        participant_id: Ecto.UUID.generate(),
        campaign_id: Ecto.UUID.generate()
      }

      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).challenge_id
    end

    test "invalid changeset when campaign_id is missing" do
      attrs = %{
        participant_id: Ecto.UUID.generate(),
        challenge_id: Ecto.UUID.generate()
      }

      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).campaign_id
    end

    test "invalid changeset when all fields are missing" do
      changeset = ParticipantChallenge.changeset(%ParticipantChallenge{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).participant_id
      assert "can't be blank" in errors_on(changeset).challenge_id
      assert "can't be blank" in errors_on(changeset).campaign_id
    end
  end

  describe "changeset/2 - uniqueness constraint violation" do
    setup do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Create campaign-challenge association
      campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      participant =
        %Participant{}
        |> Participant.changeset(%{
          tenant_id: tenant.id,
          name: "John Doe",
          nickname: "johndoe_unique"
        })
        |> Repo.insert!()

      %{
        tenant: tenant,
        campaign: campaign,
        challenge: challenge,
        campaign_challenge: campaign_challenge,
        participant: participant
      }
    end

    test "enforces unique constraint on (participant_id, challenge_id)", %{
      campaign: campaign,
      challenge: challenge,
      participant: participant
    } do
      # Insert first association
      attrs = %{
        participant_id: participant.id,
        challenge_id: challenge.id,
        campaign_id: campaign.id
      }

      changeset1 = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)
      {:ok, _} = Repo.insert(changeset1)

      # Try to insert duplicate association
      changeset2 = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset2)
      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same participant in different challenges", %{
      campaign: campaign,
      participant: participant
    } do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      # Create campaign-challenge associations
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      # Insert first association
      attrs1 = %{
        participant_id: participant.id,
        challenge_id: challenge1.id,
        campaign_id: campaign.id
      }

      changeset1 = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs1)
      {:ok, _} = Repo.insert(changeset1)

      # Insert second association with different challenge
      attrs2 = %{
        participant_id: participant.id,
        challenge_id: challenge2.id,
        campaign_id: campaign.id
      }

      changeset2 = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs2)

      assert {:ok, _} = Repo.insert(changeset2)
    end

    test "allows different participants in same challenge", %{
      tenant: tenant,
      campaign: campaign,
      challenge: challenge
    } do
      participant1 =
        %Participant{}
        |> Participant.changeset(%{
          tenant_id: tenant.id,
          name: "John Doe",
          nickname: "johndoe_diff1"
        })
        |> Repo.insert!()

      participant2 =
        %Participant{}
        |> Participant.changeset(%{
          tenant_id: tenant.id,
          name: "Jane Doe",
          nickname: "janedoe_diff2"
        })
        |> Repo.insert!()

      # Insert first association
      attrs1 = %{
        participant_id: participant1.id,
        challenge_id: challenge.id,
        campaign_id: campaign.id
      }

      changeset1 = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs1)
      {:ok, _} = Repo.insert(changeset1)

      # Insert second association with different participant
      attrs2 = %{
        participant_id: participant2.id,
        challenge_id: challenge.id,
        campaign_id: campaign.id
      }

      changeset2 = ParticipantChallenge.changeset(%ParticipantChallenge{}, attrs2)

      assert {:ok, _} = Repo.insert(changeset2)
    end
  end
end
