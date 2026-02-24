# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CampaignsApi.Repo.insert!(%CampaignsApi.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias CampaignsApi.Challenges.Challenge
alias CampaignsApi.Messaging.ChallengePublisher
alias CampaignsApi.Repo

IO.puts("Cleaning existing challenge data...")
Repo.delete_all(CampaignsApi.CampaignManagement.CampaignChallenge)
Repo.delete_all(Challenge)

challenges = [
  %{
    external_id: "purchase-frequency",
    name: "Purchase Frequency",
    description: "Rewards customers for making frequent purchases",
    metadata: %{
      "type" => "transaction",
      "category" => "engagement",
      "difficulty" => "easy"
    }
  },
  %{
    external_id: "high-value-transaction",
    name: "High Value Transaction",
    description: "Rewards customers for high-value purchases",
    metadata: %{
      "type" => "transaction",
      "category" => "revenue",
      "difficulty" => "medium"
    }
  },
  %{
    external_id: "loyalty-milestone",
    name: "Loyalty Milestone",
    description: "Rewards long-term customer loyalty",
    metadata: %{
      "type" => "milestone",
      "category" => "retention",
      "difficulty" => "hard"
    }
  },
  %{
    external_id: "referral-program",
    name: "Referral Program",
    description: "Rewards customers for referring new customers",
    metadata: %{
      "type" => "referral",
      "category" => "acquisition",
      "difficulty" => "medium"
    }
  },
  %{
    external_id: "social-media-engagement",
    name: "Social Media Engagement",
    description: "Rewards customers for social media interactions",
    metadata: %{
      "type" => "social",
      "category" => "engagement",
      "difficulty" => "easy"
    }
  }
]

IO.puts("Publishing challenge messages...")

Enum.each(challenges, fn challenge ->
  case ChallengePublisher.publish_challenge(challenge) do
    :ok ->
      IO.puts("✓ Published challenge: #{challenge.external_id}")

    {:error, reason} ->
      raise "Failed to publish challenge #{challenge.external_id}: #{inspect(reason)}"
  end
end)

expected_count = length(challenges)
wait_timeout_ms = 10_000
poll_interval_ms = 200
started_at = System.monotonic_time(:millisecond)

wait_for_count = fn wait_for_count ->
  current_count = Repo.aggregate(Challenge, :count)
  elapsed_ms = System.monotonic_time(:millisecond) - started_at

  cond do
    current_count >= expected_count ->
      :ok

    elapsed_ms >= wait_timeout_ms ->
      raise "Timed out waiting for challenge consumer to persist messages"

    true ->
      Process.sleep(poll_interval_ms)
      wait_for_count.(wait_for_count)
  end
end

wait_for_count.(wait_for_count)

IO.puts("\n✅ Challenge seed completed via RabbitMQ queue")
IO.puts("\nSummary:")
IO.puts("  - #{length(challenges)} messages published")
IO.puts("  - #{Repo.aggregate(Challenge, :count)} challenges persisted")
IO.puts("\nPublished external IDs:")
Enum.each(challenges, fn challenge -> IO.puts("  - #{challenge.external_id}") end)
