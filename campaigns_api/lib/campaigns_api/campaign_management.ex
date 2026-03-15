defmodule CampaignsApi.CampaignManagement do
  @moduledoc """
  Public context facade for campaign management operations.

  Internally, responsibilities are split into subcontexts:
  - `CampaignsApi.CampaignManagement.Campaigns`
  - `CampaignsApi.CampaignManagement.CampaignChallenges`
  - `CampaignsApi.CampaignManagement.Participants`
  """

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.CampaignManagement.CampaignChallenge
  alias CampaignsApi.CampaignManagement.Campaigns, as: CampaignsContext
  alias CampaignsApi.CampaignManagement.CampaignChallenges, as: CampaignChallengesContext
  alias CampaignsApi.CampaignManagement.CampaignParticipant
  alias CampaignsApi.CampaignManagement.Participant
  alias CampaignsApi.CampaignManagement.ParticipantChallenge
  alias CampaignsApi.CampaignManagement.Participants, as: ParticipantsContext
  alias CampaignsApi.Challenges.Challenge, as: ChallengeSchema
  alias CampaignsApi.Pagination

  @type product_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type participant_id :: Ecto.UUID.t()
  @type challenge_id :: Ecto.UUID.t()
  @type attrs :: map()

  @spec list_campaigns(product_id(), Pagination.pagination_opts()) ::
          Pagination.pagination_result(Campaign.t())
  defdelegate list_campaigns(product_id, opts \\ []), to: CampaignsContext

  @spec get_campaign(product_id(), campaign_id()) :: Campaign.t() | nil
  defdelegate get_campaign(product_id, campaign_id), to: CampaignsContext

  @spec create_campaign(product_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_campaign(product_id, attrs), to: CampaignsContext

  @spec update_campaign(product_id(), campaign_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, :not_found | Ecto.Changeset.t()}
  defdelegate update_campaign(product_id, campaign_id, attrs), to: CampaignsContext

  @spec delete_campaign(product_id(), campaign_id()) :: {:ok, Campaign.t()} | {:error, :not_found}
  defdelegate delete_campaign(product_id, campaign_id), to: CampaignsContext

  @spec list_campaign_challenges(product_id(), campaign_id(), Pagination.pagination_opts()) ::
          Pagination.pagination_result(CampaignChallenge.t())
  defdelegate list_campaign_challenges(product_id, campaign_id, opts \\ []),
    to: CampaignChallengesContext

  @spec get_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t()) ::
          CampaignChallenge.t() | nil
  defdelegate get_campaign_challenge(product_id, campaign_id, campaign_challenge_id),
    to: CampaignChallengesContext

  @spec create_campaign_challenge(product_id(), campaign_id(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :campaign_not_found | Ecto.Changeset.t()}
  defdelegate create_campaign_challenge(product_id, campaign_id, attrs),
    to: CampaignChallengesContext

  @spec update_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found | Ecto.Changeset.t()}
  defdelegate update_campaign_challenge(product_id, campaign_id, campaign_challenge_id, attrs),
    to: CampaignChallengesContext

  @spec delete_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found}
  defdelegate delete_campaign_challenge(product_id, campaign_id, campaign_challenge_id),
    to: CampaignChallengesContext

  @spec create_participant(product_id(), attrs()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_participant(product_id, attrs), to: ParticipantsContext

  @spec list_participants(product_id(), keyword()) ::
          Pagination.pagination_result(Participant.t())
  defdelegate list_participants(product_id, opts \\ []), to: ParticipantsContext

  @spec get_participant(product_id(), participant_id()) :: Participant.t() | nil
  defdelegate get_participant(product_id, participant_id), to: ParticipantsContext

  @spec update_participant(product_id(), participant_id(), attrs()) ::
          {:ok, Participant.t()} | {:error, :not_found | Ecto.Changeset.t()}
  defdelegate update_participant(product_id, participant_id, attrs), to: ParticipantsContext

  @spec delete_participant(product_id(), participant_id()) ::
          {:ok, Participant.t()} | {:error, :not_found}
  defdelegate delete_participant(product_id, participant_id), to: ParticipantsContext

  @spec associate_participant_with_campaign(product_id(), participant_id(), campaign_id()) ::
          {:ok, CampaignParticipant.t()} | {:error, :product_mismatch | Ecto.Changeset.t()}
  defdelegate associate_participant_with_campaign(product_id, participant_id, campaign_id),
    to: ParticipantsContext

  @spec disassociate_participant_from_campaign(product_id(), participant_id(), campaign_id()) ::
          {:ok, CampaignParticipant.t()} | {:error, :not_found}
  defdelegate disassociate_participant_from_campaign(product_id, participant_id, campaign_id),
    to: ParticipantsContext

  @spec list_campaigns_for_participant(
          product_id(),
          participant_id(),
          Pagination.pagination_opts()
        ) ::
          Pagination.pagination_result(Campaign.t())
  defdelegate list_campaigns_for_participant(product_id, participant_id, opts \\ []),
    to: ParticipantsContext

  @spec list_participants_for_campaign(product_id(), campaign_id(), Pagination.pagination_opts()) ::
          Pagination.pagination_result(Participant.t())
  defdelegate list_participants_for_campaign(product_id, campaign_id, opts \\ []),
    to: ParticipantsContext

  @spec associate_participant_with_challenge(product_id(), participant_id(), challenge_id()) ::
          {:ok, ParticipantChallenge.t()}
          | {:error, :product_mismatch | :participant_not_in_campaign | Ecto.Changeset.t()}
  defdelegate associate_participant_with_challenge(product_id, participant_id, challenge_id),
    to: ParticipantsContext

  @spec disassociate_participant_from_challenge(product_id(), participant_id(), challenge_id()) ::
          {:ok, ParticipantChallenge.t()} | {:error, :not_found}
  defdelegate disassociate_participant_from_challenge(product_id, participant_id, challenge_id),
    to: ParticipantsContext

  @spec list_challenges_for_participant(product_id(), participant_id(), keyword()) ::
          Pagination.pagination_result(ChallengeSchema.t())
  defdelegate list_challenges_for_participant(product_id, participant_id, opts \\ []),
    to: ParticipantsContext

  @spec list_participants_for_challenge(
          product_id(),
          challenge_id(),
          Pagination.pagination_opts()
        ) ::
          Pagination.pagination_result(Participant.t())
  defdelegate list_participants_for_challenge(product_id, challenge_id, opts \\ []),
    to: ParticipantsContext
end
