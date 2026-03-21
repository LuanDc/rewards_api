defmodule ChallengesScheduler.CampaignCalendars do
  @moduledoc """
  Read-model projections for campaign calendars and challenge schedules.
  """

  import Ecto.Query

  alias ChallengesScheduler.CampaignCalendars.CampaignCalendar
  alias ChallengesScheduler.CampaignCalendars.ChallengeSchedule
  alias ChallengesScheduler.Repo

  @type attrs :: map()

  @spec upsert_campaign(attrs()) :: {:ok, CampaignCalendar.t()} | {:error, Ecto.Changeset.t()}
  def upsert_campaign(attrs) do
    normalized = normalize_campaign_attrs(attrs)

    %CampaignCalendar{}
    |> CampaignCalendar.changeset(normalized)
    |> Repo.insert(
      conflict_target: [:id],
      on_conflict:
        {:replace,
         [:product_id, :name, :description, :start_time, :end_time, :status, :updated_at]}
    )
  end

  @spec delete_campaign(Ecto.UUID.t()) :: :ok
  def delete_campaign(campaign_id) do
    from(c in CampaignCalendar, where: c.id == ^campaign_id)
    |> Repo.delete_all()

    :ok
  end

  @spec upsert_challenge_schedule(attrs()) ::
          {:ok, ChallengeSchedule.t()} | {:error, Ecto.Changeset.t()}
  def upsert_challenge_schedule(attrs) do
    normalized = normalize_challenge_schedule_attrs(attrs)

    %ChallengeSchedule{}
    |> ChallengeSchedule.changeset(normalized)
    |> Repo.insert(
      conflict_target: [:id],
      on_conflict: {
        :replace,
        [
          :product_id,
          :campaign_id,
          :challenge_id,
          :display_name,
          :display_description,
          :evaluation_frequency,
          :reward_points,
          :configuration,
          :updated_at
        ]
      }
    )
  end

  @spec delete_challenge_schedule(Ecto.UUID.t()) :: :ok
  def delete_challenge_schedule(campaign_challenge_id) do
    from(cs in ChallengeSchedule, where: cs.id == ^campaign_challenge_id)
    |> Repo.delete_all()

    :ok
  end

  @spec delete_challenge_schedules_by_challenge(Ecto.UUID.t()) :: :ok
  def delete_challenge_schedules_by_challenge(challenge_id) do
    from(cs in ChallengeSchedule, where: cs.challenge_id == ^challenge_id)
    |> Repo.delete_all()

    :ok
  end

  defp normalize_campaign_attrs(attrs) do
    %{
      id: get_field(attrs, :id),
      product_id: get_field(attrs, :product_id),
      name: get_field(attrs, :name),
      description: get_field(attrs, :description),
      start_time: get_field(attrs, :start_time),
      end_time: get_field(attrs, :end_time),
      status: get_field(attrs, :status)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_challenge_schedule_attrs(attrs) do
    %{
      id: get_field(attrs, :id),
      product_id: get_field(attrs, :product_id),
      campaign_id: get_field(attrs, :campaign_id),
      challenge_id: get_field(attrs, :challenge_id),
      display_name: get_field(attrs, :display_name),
      display_description: get_field(attrs, :display_description),
      evaluation_frequency: get_field(attrs, :evaluation_frequency),
      reward_points: get_field(attrs, :reward_points),
      configuration: get_field(attrs, :configuration)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp get_field(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end
end
