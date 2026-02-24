ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CampaignsApi.Repo, :manual)

{:ok, _} = Application.ensure_all_started(:ex_machina)

# Property-based testing configuration
# Note: max_runs is configured per property test using the max_runs option
# All property tests in this codebase use max_runs: 50 for faster feedback
# while maintaining good coverage (reduced from default 100)
#
# To run tests excluding property tests (fast feedback):
# mix test --exclude property
#
# To run only property tests (full validation):
# mix test --only property
