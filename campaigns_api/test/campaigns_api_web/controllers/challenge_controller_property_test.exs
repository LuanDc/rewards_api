defmodule CampaignsApiWeb.ChallengeControllerPropertyTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  setup %{conn: conn} do
    tenant = insert(:tenant)
    token = jwt_token(tenant.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, tenant: tenant}
  end

  describe "Property 1: List Endpoint Returns Complete Challenge Data" do
    @doc """
    **Feature: campaign-criteria-api, Property 1: List Endpoint Returns Complete Challenge Data**

    For any request to GET /api/challenges, the response should contain a paginated list
    where each challenge includes all required fields: id, name, description, metadata,
    inserted_at, updated_at.

    **Validates: Requirements 3.4, 4.1**
    """
    @tag :property
    property "list endpoint returns challenges with all required fields", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create a challenge for this iteration
        challenge = insert(:challenge)

        # Execute: Request the list endpoint
        response_conn = get(conn, ~p"/api/challenges?limit=100")

        # Assert: Verify response structure
        response = json_response(response_conn, 200)
        assert %{"data" => data, "has_more" => has_more, "next_cursor" => _cursor} = response

        assert is_list(data)
        assert is_boolean(has_more)
        assert data != [], "Expected at least 1 challenge in response"

        # Find our challenge in the response
        our_challenge = Enum.find(data, fn c -> c["id"] == challenge.id end)
        assert our_challenge != nil, "Challenge #{challenge.id} not found in response"

        # Verify the challenge has all required fields
        assert Map.has_key?(our_challenge, "id")
        assert Map.has_key?(our_challenge, "name")
        assert Map.has_key?(our_challenge, "description")
        assert Map.has_key?(our_challenge, "metadata")
        assert Map.has_key?(our_challenge, "inserted_at")
        assert Map.has_key?(our_challenge, "updated_at")

        # Verify field types
        assert is_binary(our_challenge["id"])
        assert is_binary(our_challenge["name"])
        assert is_binary(our_challenge["description"]) or is_nil(our_challenge["description"])
        assert is_map(our_challenge["metadata"]) or is_nil(our_challenge["metadata"])
        assert is_binary(our_challenge["inserted_at"])
        assert is_binary(our_challenge["updated_at"])

        # Verify timestamps are valid ISO8601 format
        assert {:ok, _, _} = DateTime.from_iso8601(our_challenge["inserted_at"])
        assert {:ok, _, _} = DateTime.from_iso8601(our_challenge["updated_at"])

        # Verify field values match what we created
        assert our_challenge["id"] == challenge.id
        assert our_challenge["name"] == challenge.name
        assert our_challenge["description"] == challenge.description
        assert our_challenge["metadata"] == challenge.metadata
      end
    end
  end

  describe "Property 2: Challenges Ordered by Insertion Time" do
    @doc """
    **Feature: campaign-challenge-api, Property 2: Challenges Ordered by Insertion Time**

    For any request to GET /api/challenges, the returned challenges should be ordered
    by inserted_at in descending order (most recent first).

    **Validates: Requirements 4.2**
    """
    @tag :property
    property "challenges are ordered by inserted_at descending", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create at least 2 challenges to ensure there's data to test
        # We don't need to control their position in the global list,
        # we just need to verify that whatever challenges are returned are properly ordered
        _challenge1 = insert(:challenge)
        _challenge2 = insert(:challenge)

        # Execute: Request the list endpoint
        response_conn = get(conn, ~p"/api/challenges?limit=100")

        # Assert: Verify response structure
        response = json_response(response_conn, 200)
        assert %{"data" => data} = response
        assert is_list(data)
        assert length(data) >= 2, "Expected at least 2 challenges in response"

        # Extract all timestamps from the response
        timestamps =
          Enum.map(data, fn c ->
            {:ok, dt, _} = DateTime.from_iso8601(c["inserted_at"])
            dt
          end)

        # Verify they are ordered by inserted_at descending (most recent first)
        # Compare each pair of consecutive timestamps
        timestamps
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [first, second] ->
          assert DateTime.compare(first, second) in [:gt, :eq],
                 "Challenge with inserted_at #{first} should come before or equal to #{second}. " <>
                 "Challenges are not properly ordered by inserted_at descending."
        end)
      end
    end
  end

  describe "Property 3: Cursor Pagination Filters Correctly" do
    @doc """
    **Feature: campaign-challenge-api, Property 3: Cursor Pagination Filters Correctly**

    For any request to GET /api/challenges with a cursor parameter, all returned challenges
    should have inserted_at timestamps before the cursor value.

    **Validates: Requirements 4.3**
    """
    @tag :property
    property "cursor pagination filters challenges correctly", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create multiple challenges to ensure we have data
        _challenges = insert_list(5, :challenge)

        # Get the first page without cursor
        first_page_conn = get(conn, ~p"/api/challenges?limit=2")
        first_page = json_response(first_page_conn, 200)
        assert %{"data" => first_data, "next_cursor" => cursor} = first_page
        assert first_data != [], "Expected at least 1 challenge in first page"

        # If we have a cursor, use it to get the next page
        if cursor do
          # Execute: Request with cursor
          second_page_conn = get(conn, ~p"/api/challenges?limit=2&cursor=#{cursor}")
          second_page = json_response(second_page_conn, 200)
          assert %{"data" => second_data} = second_page

          # Parse the cursor timestamp
          {:ok, cursor_dt, _} = DateTime.from_iso8601(cursor)

          # Assert: All challenges in the second page should have inserted_at < cursor
          for challenge <- second_data do
            {:ok, challenge_dt, _} = DateTime.from_iso8601(challenge["inserted_at"])

            assert DateTime.compare(challenge_dt, cursor_dt) == :lt,
                   "Challenge with inserted_at #{challenge["inserted_at"]} should be before cursor #{cursor}. " <>
                   "Cursor pagination is not filtering correctly."
          end

          # Assert: No challenge from the first page should appear in the second page
          first_ids = MapSet.new(first_data, & &1["id"])
          second_ids = MapSet.new(second_data, & &1["id"])
          intersection = MapSet.intersection(first_ids, second_ids)

          assert MapSet.size(intersection) == 0,
                 "Found #{MapSet.size(intersection)} challenges appearing in both pages. " <>
                 "Cursor pagination should not return duplicate challenges."
        end
      end
    end
  end

  describe "Property 4: Limit Parameter Enforced" do
    @doc """
    **Feature: campaign-challenge-api, Property 4: Limit Parameter Enforced**

    For any request to GET /api/challenges with a limit parameter, the number of returned
    challenges should not exceed the specified limit, with a maximum of 100.

    **Validates: Requirements 4.4**
    """
    @tag :property
    property "limit parameter enforces maximum number of results", %{conn: conn} do
      check all(limit <- integer(1..150), max_runs: 20) do
        # Setup: Create more challenges than the limit to ensure we can test enforcement
        num_challenges = max(limit + 5, 10)
        _challenges = insert_list(num_challenges, :challenge)

        # Execute: Request with the generated limit
        response_conn = get(conn, ~p"/api/challenges?limit=#{limit}")

        # Assert: Verify response structure
        response = json_response(response_conn, 200)
        assert %{"data" => data} = response
        assert is_list(data)

        # The effective limit should be min(limit, 100) since 100 is the maximum
        effective_limit = min(limit, 100)

        # Assert: Number of returned challenges should not exceed the effective limit
        assert length(data) <= effective_limit,
               "Expected at most #{effective_limit} challenges, but got #{length(data)}. " <>
               "Limit parameter is not being enforced correctly."

        # Additional check: If we have enough challenges in the database,
        # we should get exactly the effective limit (unless there are fewer challenges total)
        if num_challenges >= effective_limit do
          assert length(data) == effective_limit,
                 "Expected exactly #{effective_limit} challenges when database has #{num_challenges}, " <>
                 "but got #{length(data)}."
        end
      end
    end
  end

  describe "Property 5: Pagination Metadata Accuracy" do
    @doc """
    **Feature: campaign-challenge-api, Property 5: Pagination Metadata Accuracy**

    For any request to GET /api/challenges, if more challenges exist beyond the current page,
    the response should include a next_cursor field pointing to the last challenge's inserted_at
    timestamp, and has_more should be true.

    **Validates: Requirements 4.5**
    """
    @tag :property
    property "pagination metadata is accurate when more results exist", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create enough challenges to ensure pagination
        # We need at least limit + 1 challenges to test has_more = true
        limit = 3
        num_challenges = limit + 2
        _challenges = insert_list(num_challenges, :challenge)

        # Execute: Request with a limit smaller than total challenges
        response_conn = get(conn, ~p"/api/challenges?limit=#{limit}")

        # Assert: Verify response structure
        response = json_response(response_conn, 200)
        assert %{"data" => data, "has_more" => has_more, "next_cursor" => next_cursor} = response
        assert is_list(data)
        assert length(data) == limit, "Expected exactly #{limit} challenges in response"

        # Assert: has_more should be true since we have more challenges than the limit
        assert has_more == true,
               "Expected has_more to be true when more challenges exist beyond the page"

        # Assert: next_cursor should be present and match the last challenge's inserted_at
        assert next_cursor != nil, "Expected next_cursor to be present when has_more is true"

        last_challenge = List.last(data)
        assert last_challenge != nil, "Expected at least one challenge in data"

        assert next_cursor == last_challenge["inserted_at"],
               "Expected next_cursor (#{next_cursor}) to match last challenge's inserted_at (#{last_challenge["inserted_at"]})"

        # Verify next_cursor is a valid ISO8601 timestamp
        assert {:ok, cursor_dt, _} = DateTime.from_iso8601(next_cursor)

        # Additional verification: Use the cursor to get the next page
        next_page_conn = get(conn, ~p"/api/challenges?limit=#{limit}&cursor=#{next_cursor}")
        next_page = json_response(next_page_conn, 200)
        assert %{"data" => next_data} = next_page

        # Assert: The next page should have different challenges
        first_page_ids = MapSet.new(data, & &1["id"])
        next_page_ids = MapSet.new(next_data, & &1["id"])
        intersection = MapSet.intersection(first_page_ids, next_page_ids)

        assert MapSet.size(intersection) == 0,
               "Expected no overlap between pages, but found #{MapSet.size(intersection)} duplicate challenges"

        # Assert: All challenges in next page should have inserted_at < cursor
        for challenge <- next_data do
          {:ok, challenge_dt, _} = DateTime.from_iso8601(challenge["inserted_at"])

          assert DateTime.compare(challenge_dt, cursor_dt) == :lt,
                 "Challenge in next page should have inserted_at before cursor"
        end
      end
    end

    @tag :property
    property "pagination metadata when no more results exist", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Get the total count of challenges in the database
        first_conn = get(conn, ~p"/api/challenges?limit=1000")
        first_response = json_response(first_conn, 200)
        total_challenges = length(first_response["data"])

        # Execute: Request with a limit larger than total challenges
        limit = total_challenges + 10
        response_conn = get(conn, ~p"/api/challenges?limit=#{limit}")

        # Assert: Verify response structure
        response = json_response(response_conn, 200)
        assert %{"data" => data, "has_more" => has_more, "next_cursor" => next_cursor} = response
        assert is_list(data)

        # Assert: We should get all challenges
        assert length(data) == total_challenges,
               "Expected to get all #{total_challenges} challenges when limit is #{limit}"

        # Assert: has_more should be false since we got all challenges
        assert has_more == false,
               "Expected has_more to be false when all challenges fit in one page"

        # Assert: next_cursor should be nil when has_more is false
        assert next_cursor == nil,
               "Expected next_cursor to be nil when has_more is false, but got #{inspect(next_cursor)}"
      end
    end
  end

  describe "Property 6: Global Challenge Availability" do
    @doc """
    **Feature: campaign-challenge-api, Property 6: Global Challenge Availability**

    For any two different authenticated tenants, both should receive the same set of challenges
    when querying GET /api/challenges (challenges are not tenant-filtered).

    **Validates: Requirements 4.9, 6.1, 6.2**
    """
    @tag :property
    property "all tenants see the same challenges" do
      check all(num_tenants <- integer(2..5), max_runs: 20) do
        # Setup: Create multiple tenants
        tenants = insert_list(num_tenants, :tenant)

        # Setup: Create a set of challenges that should be visible to all tenants
        num_challenges = Enum.random(3..10)
        _challenges = insert_list(num_challenges, :challenge)

        # Execute: Get challenges for each tenant
        results =
          Enum.map(tenants, fn tenant ->
            token = jwt_token(tenant.id)

            conn =
              build_conn()
              |> put_req_header("authorization", "Bearer #{token}")
              |> get(~p"/api/challenges?limit=100")

            json_response(conn, 200)
          end)

        # Assert: All tenants should receive successful responses
        assert length(results) == num_tenants,
               "Expected #{num_tenants} responses, got #{length(results)}"

        # Extract challenge IDs from each tenant's response
        challenge_id_sets =
          Enum.map(results, fn result ->
            assert %{"data" => data} = result
            assert is_list(data)

            data
            |> Enum.map(& &1["id"])
            |> MapSet.new()
          end)

        # Assert: All tenants should see the same set of challenge IDs
        [first_set | rest_sets] = challenge_id_sets

        for {tenant_set, index} <- Enum.with_index(rest_sets, 1) do
          assert MapSet.equal?(first_set, tenant_set),
                 "Tenant #{index + 1} sees different challenges than tenant 1. " <>
                   "Expected challenges to be global (not tenant-filtered). " <>
                   "Tenant 1 IDs: #{inspect(MapSet.to_list(first_set))}, " <>
                   "Tenant #{index + 1} IDs: #{inspect(MapSet.to_list(tenant_set))}"
        end

        # Additional verification: Check that the challenge data is identical, not just IDs
        [first_result | rest_results] = results
        first_data = first_result["data"] |> Enum.sort_by(& &1["id"])

        for {result, index} <- Enum.with_index(rest_results, 1) do
          result_data = result["data"] |> Enum.sort_by(& &1["id"])

          assert length(first_data) == length(result_data),
                 "Tenant #{index + 1} received different number of challenges than tenant 1"

          # Compare each challenge field by field
          Enum.zip(first_data, result_data)
          |> Enum.each(fn {first_challenge, result_challenge} ->
            assert first_challenge["id"] == result_challenge["id"],
                   "Challenge IDs don't match between tenants"

            assert first_challenge["name"] == result_challenge["name"],
                   "Challenge names don't match for ID #{first_challenge["id"]}"

            assert first_challenge["description"] == result_challenge["description"],
                   "Challenge descriptions don't match for ID #{first_challenge["id"]}"

            assert first_challenge["metadata"] == result_challenge["metadata"],
                   "Challenge metadata doesn't match for ID #{first_challenge["id"]}"

            assert first_challenge["inserted_at"] == result_challenge["inserted_at"],
                   "Challenge inserted_at doesn't match for ID #{first_challenge["id"]}"

            assert first_challenge["updated_at"] == result_challenge["updated_at"],
                   "Challenge updated_at doesn't match for ID #{first_challenge["id"]}"
          end)
        end
      end
    end

    @tag :property
    property "tenant-specific authentication still required for challenge access" do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create a challenge
        _challenge = insert(:challenge)

        # Execute: Attempt to access challenges without authentication
        conn = build_conn() |> get(~p"/api/challenges")

        # Assert: Should receive 401 Unauthorized (authentication required)
        # Note: The actual status code depends on the RequireAuth plug implementation
        # It should be either 401 or 403
        assert conn.status in [401, 403],
               "Expected 401 or 403 when accessing challenges without authentication, got #{conn.status}"
      end
    end

    @tag :property
    property "suspended and deleted tenants cannot access challenges" do
      check all(tenant_status <- member_of([:suspended, :deleted]), max_runs: 20) do
        # Setup: Create a challenge
        _challenge = insert(:challenge)

        # Setup: Create a tenant with the specified status
        tenant =
          case tenant_status do
            :suspended -> insert(:suspended_tenant)
            :deleted -> insert(:deleted_tenant)
          end

        # Execute: Attempt to access challenges with non-active tenant
        token = jwt_token(tenant.id)

        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> get(~p"/api/challenges")

        # Assert: Should receive 403 Forbidden (tenant not active)
        assert conn.status == 403,
               "Expected 403 when #{tenant_status} tenant accesses challenges, got #{conn.status}"
      end
    end
  end

  describe "Property 7: Get Challenge by ID Returns Complete Data" do
    @doc """
    **Feature: campaign-challenge-api, Property 7: Get Challenge by ID Returns Complete Data**

    For any existing challenge ID, a request to GET /api/challenges/:id should return the
    challenge with all required fields: id, name, description, metadata, inserted_at, updated_at.

    **Validates: Requirements 5.1, 5.3**
    """
    @tag :property
    property "get challenge by ID returns complete challenge data", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create a challenge for this iteration
        challenge = insert(:challenge)

        # Execute: Request the specific challenge by ID
        response_conn = get(conn, ~p"/api/challenges/#{challenge.id}")

        # Assert: Verify successful response
        response = json_response(response_conn, 200)

        # Assert: Response should be a map (not wrapped in "data")
        assert is_map(response)

        # Assert: Verify all required fields are present
        assert Map.has_key?(response, "id")
        assert Map.has_key?(response, "name")
        assert Map.has_key?(response, "description")
        assert Map.has_key?(response, "metadata")
        assert Map.has_key?(response, "inserted_at")
        assert Map.has_key?(response, "updated_at")

        # Assert: Verify field types
        assert is_binary(response["id"])
        assert is_binary(response["name"])
        assert is_binary(response["description"]) or is_nil(response["description"])
        assert is_map(response["metadata"]) or is_nil(response["metadata"])
        assert is_binary(response["inserted_at"])
        assert is_binary(response["updated_at"])

        # Assert: Verify timestamps are valid ISO8601 format
        assert {:ok, _, _} = DateTime.from_iso8601(response["inserted_at"])
        assert {:ok, _, _} = DateTime.from_iso8601(response["updated_at"])

        # Assert: Verify field values match the created challenge
        assert response["id"] == challenge.id
        assert response["name"] == challenge.name
        assert response["description"] == challenge.description
        assert response["metadata"] == challenge.metadata

        # Assert: Verify timestamps match (convert to DateTime for comparison)
        {:ok, response_inserted_at, _} = DateTime.from_iso8601(response["inserted_at"])
        {:ok, response_updated_at, _} = DateTime.from_iso8601(response["updated_at"])

        # Compare timestamps (truncate to seconds since JSON serialization may lose microseconds)
        assert DateTime.truncate(response_inserted_at, :second) ==
                 DateTime.truncate(challenge.inserted_at, :second),
               "Expected inserted_at to match"

        assert DateTime.truncate(response_updated_at, :second) ==
                 DateTime.truncate(challenge.updated_at, :second),
               "Expected updated_at to match"
      end
    end

    @tag :property
    property "get challenge by ID is consistent across multiple requests", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create a challenge
        challenge = insert(:challenge)

        # Execute: Request the same challenge multiple times
        num_requests = Enum.random(2..5)

        responses =
          Enum.map(1..num_requests, fn _ ->
            response_conn = get(conn, ~p"/api/challenges/#{challenge.id}")
            json_response(response_conn, 200)
          end)

        # Assert: All responses should be identical
        [first_response | rest_responses] = responses

        for {response, index} <- Enum.with_index(rest_responses, 1) do
          assert response == first_response,
                 "Request #{index + 1} returned different data than request 1. " <>
                   "GET by ID should be idempotent and return consistent data."
        end
      end
    end

    @tag :property
    property "get challenge by ID returns 404 for non-existent IDs", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Generate a random UUID that doesn't exist in the database
        non_existent_id = Ecto.UUID.generate()

        # Execute: Request a non-existent challenge
        response_conn = get(conn, ~p"/api/challenges/#{non_existent_id}")

        # Assert: Should return 404 Not Found
        assert response_conn.status == 404,
               "Expected 404 for non-existent challenge ID, got #{response_conn.status}"

        # Assert: Error response should be JSON with error field
        response = json_response(response_conn, 404)
        assert %{"error" => error_message} = response
        assert is_binary(error_message)
        assert error_message =~ ~r/not found/i,
               "Expected error message to mention 'not found', got: #{error_message}"
      end
    end

    @tag :property
    property "get challenge by ID works for challenges with various metadata", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create challenges with different metadata structures
        metadata_variants = [
          nil,
          %{},
          %{"type" => "evaluation"},
          %{"type" => "transaction_validation", "threshold" => 100},
          %{"nested" => %{"key" => "value"}, "array" => [1, 2, 3]},
          %{"string" => "test", "number" => 42, "boolean" => true, "null" => nil}
        ]

        metadata = Enum.random(metadata_variants)
        challenge = insert(:challenge, metadata: metadata)

        # Execute: Request the challenge
        response_conn = get(conn, ~p"/api/challenges/#{challenge.id}")

        # Assert: Verify successful response
        response = json_response(response_conn, 200)

        # Assert: Metadata should match exactly
        assert response["metadata"] == metadata,
               "Expected metadata to match. Expected: #{inspect(metadata)}, Got: #{inspect(response["metadata"])}"
      end
    end

    @tag :property
    property "get challenge by ID works for challenges with various descriptions", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create challenges with different description values
        description_variants = [
          nil,
          "",
          "Short description",
          "A much longer description with multiple sentences. This tests that longer text is properly handled.",
          "Description with special characters: !@#$%^&*()_+-=[]{}|;':\",./<>?",
          "Description with unicode: 你好世界 🌍 émojis"
        ]

        description = Enum.random(description_variants)
        challenge = insert(:challenge, description: description)

        # Execute: Request the challenge
        response_conn = get(conn, ~p"/api/challenges/#{challenge.id}")

        # Assert: Verify successful response
        response = json_response(response_conn, 200)

        # Assert: Description should match exactly
        assert response["description"] == description,
               "Expected description to match. Expected: #{inspect(description)}, Got: #{inspect(response["description"])}"
      end
    end
  end

  describe "Property 8: Error Responses Formatted as JSON" do
    @doc """
    **Feature: campaign-challenge-api, Property 8: Error Responses Formatted as JSON**

    For any error condition (404, 401, 403), the response should be formatted as structured
    JSON with an "error" field containing a descriptive message.

    **Validates: Requirements 8.5**
    """
    @tag :property
    property "404 errors return structured JSON with error field", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Generate a random non-existent UUID
        non_existent_id = Ecto.UUID.generate()

        # Execute: Request a non-existent challenge
        response_conn = get(conn, ~p"/api/challenges/#{non_existent_id}")

        # Assert: Should return 404 status
        assert response_conn.status == 404,
               "Expected 404 for non-existent challenge, got #{response_conn.status}"

        # Assert: Response should be valid JSON
        response = json_response(response_conn, 404)
        assert is_map(response), "Expected response to be a JSON object (map)"

        # Assert: Response should have an "error" field
        assert Map.has_key?(response, "error"),
               "Expected response to have an 'error' field. Got: #{inspect(response)}"

        # Assert: Error field should be a string
        assert is_binary(response["error"]),
               "Expected 'error' field to be a string, got: #{inspect(response["error"])}"

        # Assert: Error message should be non-empty
        assert String.length(response["error"]) > 0,
               "Expected 'error' field to contain a non-empty message"

        # Assert: Error message should be descriptive (mention "not found")
        assert response["error"] =~ ~r/not found/i,
               "Expected error message to mention 'not found', got: #{response["error"]}"
      end
    end

    @tag :property
    property "401 errors return structured JSON with error field" do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create a challenge
        _challenge = insert(:challenge)

        # Execute: Request without authentication
        response_conn = build_conn() |> get(~p"/api/challenges")

        # Assert: Should return 401 or 403 status (depending on plug implementation)
        assert response_conn.status in [401, 403],
               "Expected 401 or 403 for unauthenticated request, got #{response_conn.status}"

        # Assert: Response should be valid JSON
        response = json_response(response_conn, response_conn.status)
        assert is_map(response), "Expected response to be a JSON object (map)"

        # Assert: Response should have an "error" field
        assert Map.has_key?(response, "error"),
               "Expected response to have an 'error' field. Got: #{inspect(response)}"

        # Assert: Error field should be a string
        assert is_binary(response["error"]),
               "Expected 'error' field to be a string, got: #{inspect(response["error"])}"

        # Assert: Error message should be non-empty
        assert String.length(response["error"]) > 0,
               "Expected 'error' field to contain a non-empty message"
      end
    end

    @tag :property
    property "403 errors return structured JSON with error field" do
      check all(tenant_status <- member_of([:suspended, :deleted]), max_runs: 20) do
        # Setup: Create a challenge
        _challenge = insert(:challenge)

        # Setup: Create a tenant with non-active status
        tenant =
          case tenant_status do
            :suspended -> insert(:suspended_tenant)
            :deleted -> insert(:deleted_tenant)
          end

        # Execute: Request with non-active tenant
        token = jwt_token(tenant.id)

        response_conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> get(~p"/api/challenges")

        # Assert: Should return 403 status
        assert response_conn.status == 403,
               "Expected 403 for #{tenant_status} tenant, got #{response_conn.status}"

        # Assert: Response should be valid JSON
        response = json_response(response_conn, 403)
        assert is_map(response), "Expected response to be a JSON object (map)"

        # Assert: Response should have an "error" field
        assert Map.has_key?(response, "error"),
               "Expected response to have an 'error' field. Got: #{inspect(response)}"

        # Assert: Error field should be a string
        assert is_binary(response["error"]),
               "Expected 'error' field to be a string, got: #{inspect(response["error"])}"

        # Assert: Error message should be non-empty
        assert String.length(response["error"]) > 0,
               "Expected 'error' field to contain a non-empty message"
      end
    end

    @tag :property
    property "error responses contain only expected fields", %{conn: conn} do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Generate a non-existent UUID
        non_existent_id = Ecto.UUID.generate()

        # Execute: Request a non-existent challenge
        response_conn = get(conn, ~p"/api/challenges/#{non_existent_id}")

        # Assert: Response should be valid JSON
        response = json_response(response_conn, 404)

        # Assert: Response should only contain the "error" field (no extra fields)
        # This ensures consistent error response structure
        assert Map.keys(response) == ["error"],
               "Expected error response to only contain 'error' field, got: #{inspect(Map.keys(response))}"
      end
    end

    @tag :property
    property "error responses are consistent across multiple error conditions" do
      check all(_iteration <- integer(1..20), max_runs: 20) do
        # Setup: Create multiple error scenarios
        non_existent_id = Ecto.UUID.generate()

        # Scenario 1: 404 error
        error_404_conn = build_conn()
        tenant = insert(:tenant)
        token = jwt_token(tenant.id)

        error_404_conn =
          error_404_conn
          |> put_req_header("authorization", "Bearer #{token}")
          |> get(~p"/api/challenges/#{non_existent_id}")

        response_404 = json_response(error_404_conn, 404)

        # Scenario 2: 401/403 error (no auth)
        error_401_conn = build_conn() |> get(~p"/api/challenges")
        response_401 = json_response(error_401_conn, error_401_conn.status)

        # Scenario 3: 403 error (suspended tenant)
        suspended_tenant = insert(:suspended_tenant)
        suspended_token = jwt_token(suspended_tenant.id)

        error_403_conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{suspended_token}")
          |> get(~p"/api/challenges")

        response_403 = json_response(error_403_conn, 403)

        # Assert: All error responses should have the same structure
        assert Map.keys(response_404) == ["error"],
               "404 response should only have 'error' field"

        assert Map.keys(response_401) == ["error"],
               "401/403 response should only have 'error' field"

        assert Map.keys(response_403) == ["error"],
               "403 response should only have 'error' field"

        # Assert: All error messages should be strings
        assert is_binary(response_404["error"])
        assert is_binary(response_401["error"])
        assert is_binary(response_403["error"])

        # Assert: All error messages should be non-empty
        assert String.length(response_404["error"]) > 0
        assert String.length(response_401["error"]) > 0
        assert String.length(response_403["error"]) > 0
      end
    end
  end
end
