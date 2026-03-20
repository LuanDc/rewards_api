defmodule ChallengesScheduler.Repo do
  use Ecto.Repo,
    otp_app: :challenges_scheduler,
    adapter: Ecto.Adapters.Postgres
end
