defmodule CampaignsApiMessaging.ChallengeMessageTest do
  use ExUnit.Case, async: true

  alias CampaignsApiMessaging.ChallengeMessage

  describe "decode/1" do
    test "decodes valid challenge payload" do
      payload =
        Jason.encode!(%{
          "schema_version" => 1,
          "external_id" => "challenge-purchase-frequency",
          "name" => "Purchase Frequency",
          "description" => "Rewards frequent purchases",
          "metadata" => %{"difficulty" => "easy"}
        })

      assert {:ok, decoded} = ChallengeMessage.decode(payload)
      assert decoded.schema_version == 1
      assert decoded.external_id == "challenge-purchase-frequency"
      assert decoded.name == "Purchase Frequency"
      assert decoded.description == "Rewards frequent purchases"
      assert decoded.metadata == %{"difficulty" => "easy"}
    end

    test "returns error when required fields are missing" do
      payload = Jason.encode!(%{"schema_version" => 1, "name" => "Missing External ID"})

      assert {:error, {:invalid_payload, {:missing_fields, ["external_id"]}}} =
               ChallengeMessage.decode(payload)
    end

    test "returns error when schema_version is invalid" do
      payload =
        Jason.encode!(%{
          "schema_version" => 2,
          "external_id" => "challenge-a",
          "name" => "Challenge A"
        })

      assert {:error, {:invalid_payload, :invalid_schema_version}} =
               ChallengeMessage.decode(payload)
    end

    test "defaults metadata to empty map when metadata is nil" do
      payload =
        Jason.encode!(%{
          "schema_version" => 1,
          "external_id" => "challenge-b",
          "name" => "Challenge B",
          "metadata" => nil
        })

      assert {:ok, decoded} = ChallengeMessage.decode(payload)
      assert decoded.metadata == %{}
    end
  end

  describe "encode/1" do
    test "encodes payload map to JSON" do
      payload = %{
        schema_version: 1,
        external_id: "challenge-social-share",
        name: "Social Share",
        description: nil,
        metadata: %{"category" => "engagement"}
      }

      assert {:ok, json} = ChallengeMessage.encode(payload)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["external_id"] == "challenge-social-share"
      assert decoded["name"] == "Social Share"
    end
  end
end
