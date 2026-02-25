defmodule CampaignsApiWeb.ParticipantControllerTest do
  use CampaignsApiWeb.ConnCase, async: true

  alias CampaignsApi.CampaignManagement

  setup %{conn: conn} do
    product = insert(:product)
    token = jwt_token(product.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, product: product}
  end

  describe "POST /api/participants (create)" do
    test "creates participant with valid data", %{conn: conn, product: product} do
      params = %{
        "name" => "John Doe",
        "nickname" => "johndoe",
        "status" => "active"
      }

      conn = post(conn, ~p"/api/participants", params)

      assert %{
               "id" => _id,
               "product_id" => product_id,
               "name" => "John Doe",
               "nickname" => "johndoe",
               "status" => "active"
             } = json_response(conn, 201)

      assert product_id == product.id
    end

    test "returns 422 with validation errors for invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/participants", %{"name" => "", "nickname" => "ab"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "name") or Map.has_key?(errors, "nickname")
    end
  end

  describe "GET /api/participants (index)" do
    test "returns empty list when no participants exist", %{conn: conn} do
      conn = get(conn, ~p"/api/participants")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns participants for the product", %{conn: conn, product: product} do
      insert_list(2, :participant, product: product)

      conn = get(conn, ~p"/api/participants")

      assert %{"data" => participants, "has_more" => false} = json_response(conn, 200)
      assert length(participants) == 2
    end

    test "supports pagination with limit parameter", %{conn: conn, product: product} do
      insert_list(3, :participant, product: product)

      conn = get(conn, ~p"/api/participants?limit=2")

      assert %{"data" => participants, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(participants) == 2
      assert cursor != nil
    end

    test "supports pagination with cursor parameter", %{conn: conn, product: product} do
      insert_list(3, :participant, product: product)

      conn1 = get(conn, ~p"/api/participants?limit=2")
      response1 = json_response(conn1, 200)

      assert %{"data" => page1, "next_cursor" => cursor, "has_more" => true} = response1
      assert length(page1) == 2

      conn2 = get(conn, ~p"/api/participants?cursor=#{cursor}")
      response2 = json_response(conn2, 200)

      assert %{"data" => _page2} = response2
    end

    test "does not return participants from other products", %{conn: conn, product: product} do
      my_participant = insert(:participant, product: product)
      other_product = insert(:product)
      insert(:participant, product: other_product)

      conn = get(conn, ~p"/api/participants")

      assert %{"data" => participants} = json_response(conn, 200)
      assert length(participants) == 1
      assert hd(participants)["name"] == my_participant.name
    end

    test "filters by nickname parameter", %{conn: conn, product: product} do
      insert(:participant, product: product, nickname: "johndoe")
      insert(:participant, product: product, nickname: "janedoe")
      insert(:participant, product: product, nickname: "alice")

      conn = get(conn, ~p"/api/participants?nickname=doe")

      assert %{"data" => participants} = json_response(conn, 200)
      assert length(participants) == 2
    end
  end

  describe "GET /api/participants/:id (show)" do
    test "returns participant when it exists and belongs to product", %{
      conn: conn,
      product: product
    } do
      participant = insert(:participant, product: product)

      conn = get(conn, ~p"/api/participants/#{participant.id}")

      assert %{
               "id" => id,
               "name" => name,
               "product_id" => product_id
             } = json_response(conn, 200)

      assert id == participant.id
      assert name == participant.name
      assert product_id == product.id
    end

    test "returns 404 when participant does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/participants/#{fake_id}")

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end

    test "returns 404 when participant belongs to different product", %{conn: conn} do
      other_product = insert(:product)
      other_participant = insert(:participant, product: other_product)

      conn = get(conn, ~p"/api/participants/#{other_participant.id}")

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end
  end

  describe "PUT /api/participants/:id (update)" do
    test "updates participant with valid data", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)

      update_params = %{
        "name" => "Updated Name",
        "nickname" => "updated",
        "status" => "inactive"
      }

      conn = put(conn, ~p"/api/participants/#{participant.id}", update_params)

      assert %{
               "id" => id,
               "name" => "Updated Name",
               "nickname" => "updated",
               "status" => "inactive"
             } = json_response(conn, 200)

      assert id == participant.id
    end

    test "returns 422 with validation errors for invalid data", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)

      conn = put(conn, ~p"/api/participants/#{participant.id}", %{"name" => ""})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "name")
    end

    test "returns 404 when participant does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = put(conn, ~p"/api/participants/#{fake_id}", %{"name" => "Updated"})

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end

    test "returns 404 when participant belongs to different product", %{conn: conn} do
      other_product = insert(:product)
      other_participant = insert(:participant, product: other_product)

      conn = put(conn, ~p"/api/participants/#{other_participant.id}", %{"name" => "Hacked"})

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/participants/:id (delete)" do
    test "deletes participant successfully", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)

      conn = delete(conn, ~p"/api/participants/#{participant.id}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == participant.id
      assert CampaignManagement.get_participant(product.id, participant.id) == nil
    end

    test "returns 404 when participant does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, ~p"/api/participants/#{fake_id}")

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end

    test "returns 404 when participant belongs to different product", %{conn: conn} do
      other_product = insert(:product)
      other_participant = insert(:participant, product: other_product)

      conn = delete(conn, ~p"/api/participants/#{other_participant.id}")

      assert %{"error" => "Participant not found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/participants/:participant_id/campaigns/:campaign_id (associate_campaign)" do
    test "associates participant with campaign successfully", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)

      conn = post(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{
               "id" => _id,
               "participant_id" => participant_id,
               "campaign_id" => campaign_id
             } = json_response(conn, 201)

      assert participant_id == participant.id
      assert campaign_id == campaign.id
    end

    test "returns 403 when participant belongs to different product", %{
      conn: conn,
      product: product
    } do
      other_product = insert(:product)
      participant = insert(:participant, product: other_product)
      campaign = insert(:campaign, product: product)

      conn = post(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{"error" => "Participant or campaign not found in product"} =
               json_response(conn, 403)
    end

    test "returns 403 when campaign belongs to different product", %{conn: conn, product: product} do
      other_product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: other_product)

      conn = post(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{"error" => "Participant or campaign not found in product"} =
               json_response(conn, 403)
    end

    test "returns 422 when association already exists", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      insert(:campaign_participant, participant: participant, campaign: campaign)

      conn = post(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{"errors" => _errors} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/participants/:participant_id/campaigns/:campaign_id (disassociate_campaign)" do
    test "disassociates participant from campaign successfully", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      association = insert(:campaign_participant, participant: participant, campaign: campaign)

      conn = delete(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == association.id
    end

    test "returns 404 when association does not exist", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)

      conn = delete(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{"error" => "Association not found"} = json_response(conn, 404)
    end

    test "returns 404 when participant belongs to different product", %{
      conn: conn,
      product: product
    } do
      other_product = insert(:product)
      participant = insert(:participant, product: other_product)
      campaign = insert(:campaign, product: product)

      conn = delete(conn, ~p"/api/participants/#{participant.id}/campaigns/#{campaign.id}")

      assert %{"error" => "Association not found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/participants/:participant_id/campaigns (list_campaigns)" do
    test "returns empty list when participant has no campaigns", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)

      conn = get(conn, ~p"/api/participants/#{participant.id}/campaigns")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns campaigns for participant", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign1 = insert(:campaign, product: product)
      campaign2 = insert(:campaign, product: product)
      insert(:campaign_participant, participant: participant, campaign: campaign1)
      insert(:campaign_participant, participant: participant, campaign: campaign2)

      conn = get(conn, ~p"/api/participants/#{participant.id}/campaigns")

      assert %{"data" => campaigns, "has_more" => false} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "supports pagination with limit parameter", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)

      Enum.each(1..3, fn _ ->
        campaign = insert(:campaign, product: product)
        insert(:campaign_participant, participant: participant, campaign: campaign)
      end)

      conn = get(conn, ~p"/api/participants/#{participant.id}/campaigns?limit=2")

      assert %{"data" => campaigns, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(campaigns) == 2
      assert cursor != nil
    end
  end

  describe "GET /api/campaigns/:campaign_id/participants (list_participants)" do
    test "returns empty list when campaign has no participants", %{conn: conn, product: product} do
      campaign = insert(:campaign, product: product)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/participants")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns participants for campaign", %{conn: conn, product: product} do
      campaign = insert(:campaign, product: product)
      participant1 = insert(:participant, product: product)
      participant2 = insert(:participant, product: product)
      insert(:campaign_participant, participant: participant1, campaign: campaign)
      insert(:campaign_participant, participant: participant2, campaign: campaign)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/participants")

      assert %{"data" => participants, "has_more" => false} = json_response(conn, 200)
      assert length(participants) == 2
    end

    test "supports pagination with limit parameter", %{conn: conn, product: product} do
      campaign = insert(:campaign, product: product)

      Enum.each(1..3, fn _ ->
        participant = insert(:participant, product: product)
        insert(:campaign_participant, participant: participant, campaign: campaign)
      end)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/participants?limit=2")

      assert %{"data" => participants, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(participants) == 2
      assert cursor != nil
    end
  end

  describe "POST /api/participants/:participant_id/challenges/:challenge_id (associate_challenge)" do
    test "associates participant with challenge successfully", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      insert(:campaign_participant, participant: participant, campaign: campaign)

      conn = post(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{
               "id" => _id,
               "participant_id" => participant_id,
               "challenge_id" => challenge_id,
               "campaign_id" => campaign_id
             } = json_response(conn, 201)

      assert participant_id == participant.id
      assert challenge_id == challenge.id
      assert campaign_id == campaign.id
    end

    test "returns 403 when participant belongs to different product", %{conn: conn} do
      other_product = insert(:product)
      participant = insert(:participant, product: other_product)
      challenge = insert(:challenge)

      conn = post(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{"error" => "Participant or challenge not found in product"} =
               json_response(conn, 403)
    end

    test "returns 422 when participant not in campaign", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      conn = post(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{"error" => "Participant not associated with challenge's campaign"} =
               json_response(conn, 422)
    end

    test "returns 422 when association already exists", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      insert(:campaign_participant, participant: participant, campaign: campaign)

      insert(:participant_challenge,
        participant: participant,
        challenge: challenge,
        campaign: campaign
      )

      conn = post(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{"errors" => _errors} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/participants/:participant_id/challenges/:challenge_id (disassociate_challenge)" do
    test "disassociates participant from challenge successfully", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      insert(:campaign_participant, participant: participant, campaign: campaign)

      association =
        insert(:participant_challenge,
          participant: participant,
          challenge: challenge,
          campaign: campaign
        )

      conn = delete(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{"id" => id} = json_response(conn, 200)
      assert id == association.id
    end

    test "returns 404 when association does not exist", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      challenge = insert(:challenge)

      conn = delete(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{"error" => "Association not found"} = json_response(conn, 404)
    end

    test "returns 404 when participant belongs to different product", %{conn: conn} do
      other_product = insert(:product)
      participant = insert(:participant, product: other_product)
      challenge = insert(:challenge)

      conn = delete(conn, ~p"/api/participants/#{participant.id}/challenges/#{challenge.id}")

      assert %{"error" => "Association not found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/participants/:participant_id/challenges (list_challenges)" do
    test "returns empty list when participant has no challenges", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)

      conn = get(conn, ~p"/api/participants/#{participant.id}/challenges")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns challenges for participant", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)
      insert(:campaign_participant, participant: participant, campaign: campaign)

      insert(:participant_challenge,
        participant: participant,
        challenge: challenge1,
        campaign: campaign
      )

      insert(:participant_challenge,
        participant: participant,
        challenge: challenge2,
        campaign: campaign
      )

      conn = get(conn, ~p"/api/participants/#{participant.id}/challenges")

      assert %{"data" => challenges, "has_more" => false} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "supports pagination with limit parameter", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      insert(:campaign_participant, participant: participant, campaign: campaign)

      Enum.each(1..3, fn _ ->
        challenge = insert(:challenge)
        insert(:campaign_challenge, campaign: campaign, challenge: challenge)

        insert(:participant_challenge,
          participant: participant,
          challenge: challenge,
          campaign: campaign
        )
      end)

      conn = get(conn, ~p"/api/participants/#{participant.id}/challenges?limit=2")

      assert %{"data" => challenges, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(challenges) == 2
      assert cursor != nil
    end

    test "filters by campaign_id parameter", %{conn: conn, product: product} do
      participant = insert(:participant, product: product)
      campaign1 = insert(:campaign, product: product)
      campaign2 = insert(:campaign, product: product)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign1, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign2, challenge: challenge2)
      insert(:campaign_participant, participant: participant, campaign: campaign1)
      insert(:campaign_participant, participant: participant, campaign: campaign2)

      insert(:participant_challenge,
        participant: participant,
        challenge: challenge1,
        campaign: campaign1
      )

      insert(:participant_challenge,
        participant: participant,
        challenge: challenge2,
        campaign: campaign2
      )

      conn =
        get(conn, ~p"/api/participants/#{participant.id}/challenges?campaign_id=#{campaign1.id}")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 1
      assert hd(challenges)["id"] == challenge1.id
    end
  end

  describe "GET /api/challenges/:challenge_id/participants (list_challenge_participants)" do
    test "returns empty list when challenge has no participants", %{conn: conn} do
      challenge = insert(:challenge)

      conn = get(conn, ~p"/api/challenges/#{challenge.id}/participants")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns participants for challenge", %{conn: conn, product: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      participant1 = insert(:participant, product: product)
      participant2 = insert(:participant, product: product)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      insert(:campaign_participant, participant: participant1, campaign: campaign)
      insert(:campaign_participant, participant: participant2, campaign: campaign)

      insert(:participant_challenge,
        participant: participant1,
        challenge: challenge,
        campaign: campaign
      )

      insert(:participant_challenge,
        participant: participant2,
        challenge: challenge,
        campaign: campaign
      )

      conn = get(conn, ~p"/api/challenges/#{challenge.id}/participants")

      assert %{"data" => participants, "has_more" => false} = json_response(conn, 200)
      assert length(participants) == 2
    end

    test "supports pagination with limit parameter", %{conn: conn, product: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      Enum.each(1..3, fn _ ->
        participant = insert(:participant, product: product)
        insert(:campaign_participant, participant: participant, campaign: campaign)

        insert(:participant_challenge,
          participant: participant,
          challenge: challenge,
          campaign: campaign
        )
      end)

      conn = get(conn, ~p"/api/challenges/#{challenge.id}/participants?limit=2")

      assert %{"data" => participants, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(participants) == 2
      assert cursor != nil
    end
  end
end
