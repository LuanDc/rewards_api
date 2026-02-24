defmodule CampaignsApiMessaging.ChallengeConsumerTest do
  use CampaignsApi.DataCase, async: true

  alias Broadway.Message
  alias CampaignsApi.Challenges
  alias CampaignsApiMessaging.ChallengeConsumer

  describe "handle_message/3" do
    test "routes valid payload to challenges batcher" do
      raw_payload =
        Jason.encode!(%{
          "schema_version" => 1,
          "external_id" => "challenge-launch-week",
          "name" => "Launch Week",
          "description" => "Launch week challenge",
          "metadata" => %{"difficulty" => "medium"}
        })

      message = message(raw_payload)

      processed = ChallengeConsumer.handle_message(:default, message, %{})

      assert processed.batcher == :challenges
      assert processed.metadata.raw_payload == raw_payload
      assert processed.data.external_id == "challenge-launch-week"
      assert processed.data.name == "Launch Week"
    end

    test "marks invalid payload as failed" do
      message = message("not-json")

      processed = ChallengeConsumer.handle_message(:default, message, %{})

      assert match?({:failed, {:invalid_payload, _}}, processed.status)
    end
  end

  describe "handle_batch/4" do
    test "persists a new challenge via context upsert" do
      message = message(%{external_id: "challenge-referral", name: "Referral", metadata: %{}})

      [processed] = ChallengeConsumer.handle_batch(:challenges, [message], %{}, %{})

      assert processed.status == :ok or is_nil(processed.status)

      challenge =
        Challenges.list_challenges().data |> Enum.find(&(&1.external_id == "challenge-referral"))

      assert challenge != nil
      assert challenge.name == "Referral"
    end

    test "updates existing challenge when external_id already exists" do
      {:ok, existing} =
        Challenges.create_challenge(%{
          external_id: "challenge-upserted",
          name: "Old Name",
          metadata: %{"version" => 1}
        })

      message =
        message(%{
          external_id: "challenge-upserted",
          name: "New Name",
          metadata: %{"version" => 2}
        })

      [_processed] = ChallengeConsumer.handle_batch(:challenges, [message], %{}, %{})

      reloaded = Challenges.get_challenge(existing.id)
      assert reloaded.name == "New Name"
      assert reloaded.metadata == %{"version" => 2}
    end

    test "marks message as failed when external_id is missing" do
      message = message(%{name: "No external id"})

      [processed] = ChallengeConsumer.handle_batch(:challenges, [message], %{}, %{})

      assert processed.status == {:failed, {:processing_error, :missing_external_id}}
    end
  end

  defp message(data, metadata \\ %{}) do
    %Message{
      data: data,
      metadata: metadata,
      acknowledger: {Broadway.NoopAcknowledger, nil, nil}
    }
  end
end
