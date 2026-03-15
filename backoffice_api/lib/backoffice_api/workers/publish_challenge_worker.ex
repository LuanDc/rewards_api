defmodule BackofficeApi.Workers.PublishChallengeWorker do
  @moduledoc """
  Sends challenge events to RabbitMQ.
  """

  use Oban.Worker, queue: :challenge_events, max_attempts: 5

  alias BackofficeApiMessaging.ChallengePublisher

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"challenge" => challenge}}) do
    if messaging_enabled?() do
      ChallengePublisher.publish_challenge(challenge)
    else
      :ok
    end
  end

  def perform(_job), do: {:error, :invalid_args}

  defp messaging_enabled? do
    Application.fetch_env!(:backoffice_api, BackofficeApiMessaging)[:enabled]
  end
end
