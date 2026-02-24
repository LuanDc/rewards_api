defmodule CampaignsApi.ParticipantManagement.CampaignParticipantTest do
  use CampaignsApi.DataCase, async: true

  import CampaignsApi.Factory

  alias CampaignsApi.CampaignManagement.CampaignParticipant
  alias CampaignsApi.CampaignManagement.Participant

  describe "changeset/2 - valid association creation" do
    setup do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      participant =
        %Participant{}
        |> Participant.changeset(%{
          tenant_id: tenant.id,
          name: "John Doe",
          nickname: "johndoe"
        })
        |> Repo.insert!()

      %{tenant: tenant, campaign: campaign, participant: participant}
    end

    test "creates valid campaign-participant association", %{
      campaign: campaign,
      participant: participant
    } do
      attrs = %{
        participant_id: participant.id,
        campaign_id: campaign.id
      }

      changeset = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :participant_id) == participant.id
      assert get_change(changeset, :campaign_id) == campaign.id
    end

    test "successfully inserts campaign-participant association", %{
      campaign: campaign,
      participant: participant
    } do
      attrs = %{
        participant_id: participant.id,
        campaign_id: campaign.id
      }

      changeset = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)

      assert {:ok, campaign_participant} = Repo.insert(changeset)
      assert campaign_participant.participant_id == participant.id
      assert campaign_participant.campaign_id == campaign.id
      assert campaign_participant.id != nil
      assert campaign_participant.inserted_at != nil
      assert campaign_participant.updated_at != nil
    end
  end

  describe "changeset/2 - required field validations" do
    test "rejects association without participant_id" do
      attrs = %{
        campaign_id: Ecto.UUID.generate()
      }

      changeset = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)

      refute changeset.valid?
      assert %{participant_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects association without campaign_id" do
      attrs = %{
        participant_id: Ecto.UUID.generate()
      }

      changeset = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)

      refute changeset.valid?
      assert %{campaign_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects association with both fields missing" do
      attrs = %{}

      changeset = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert %{participant_id: ["can't be blank"]} = errors
      assert %{campaign_id: ["can't be blank"]} = errors
    end
  end

  describe "changeset/2 - uniqueness constraint violation" do
    setup do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      participant =
        %Participant{}
        |> Participant.changeset(%{
          tenant_id: tenant.id,
          name: "John Doe",
          nickname: "johndoe_unique"
        })
        |> Repo.insert!()

      %{tenant: tenant, campaign: campaign, participant: participant}
    end

    test "enforces unique constraint on (participant_id, campaign_id)", %{
      campaign: campaign,
      participant: participant
    } do
      # Insert first association
      attrs = %{
        participant_id: participant.id,
        campaign_id: campaign.id
      }

      changeset1 = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)
      {:ok, _} = Repo.insert(changeset1)

      # Try to insert duplicate association
      changeset2 = CampaignParticipant.changeset(%CampaignParticipant{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset2)
      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same participant in different campaigns", %{
      tenant: tenant,
      participant: participant
    } do
      campaign1 = insert(:campaign, tenant: tenant)
      campaign2 = insert(:campaign, tenant: tenant)

      # Insert first association
      attrs1 = %{
        participant_id: participant.id,
        campaign_id: campaign1.id
      }

      changeset1 = CampaignParticipant.changeset(%CampaignParticipant{}, attrs1)
      {:ok, _} = Repo.insert(changeset1)

      # Insert second association with different campaign
      attrs2 = %{
        participant_id: participant.id,
        campaign_id: campaign2.id
      }

      changeset2 = CampaignParticipant.changeset(%CampaignParticipant{}, attrs2)

      assert {:ok, _} = Repo.insert(changeset2)
    end

    test "allows different participants in same campaign", %{
      tenant: tenant,
      campaign: campaign
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
        campaign_id: campaign.id
      }

      changeset1 = CampaignParticipant.changeset(%CampaignParticipant{}, attrs1)
      {:ok, _} = Repo.insert(changeset1)

      # Insert second association with different participant
      attrs2 = %{
        participant_id: participant2.id,
        campaign_id: campaign.id
      }

      changeset2 = CampaignParticipant.changeset(%CampaignParticipant{}, attrs2)

      assert {:ok, _} = Repo.insert(changeset2)
    end
  end
end
