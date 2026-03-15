defmodule BackofficeApi.ChallengeManagementTest do
  use BackofficeApi.DataCase, async: true

  import Oban.Testing, only: [all_enqueued: 1]

  alias BackofficeApi.ChallengeManagement
  alias BackofficeApi.Workers.PublishChallengeWorker

  describe "create_challenge/1" do
    test "creates challenge and enqueues publish job in the same transaction" do
      attrs = %{
        "name" => "TransactionChecker",
        "description" => "Validates transaction behavior",
        "metadata" => %{"threshold" => 100}
      }

      assert {:ok, challenge} = ChallengeManagement.create_challenge(attrs)
      assert challenge.name == "TransactionChecker"
      assert is_binary(challenge.external_id)

      [job] = all_enqueued(worker: PublishChallengeWorker, repo: BackofficeApi.Repo)
      assert job.args["challenge"]["external_id"] == challenge.external_id
      assert job.args["challenge"]["name"] == challenge.name
    end

    test "returns validation errors and does not enqueue job" do
      attrs = %{"name" => "ab"}

      assert {:error, changeset} = ChallengeManagement.create_challenge(attrs)
      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)

      assert [] == all_enqueued(worker: PublishChallengeWorker, repo: BackofficeApi.Repo)
    end
  end
end
