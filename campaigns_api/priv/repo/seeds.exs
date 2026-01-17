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

alias CampaignsApi.Repo
alias CampaignsApi.Criteria.Criterion

# Clear existing criteria
Repo.delete_all(Criterion)

# Seed criteria with Faker data
criteria_list = [
  %{
    name: "Daily Login",
    description: "User must login to the app daily",
    status: "active"
  },
  %{
    name: "First Purchase",
    description: "User completes their first purchase",
    status: "active"
  },
  %{
    name: "Friend Referral",
    description: "User refers a friend who signs up",
    status: "active"
  },
  %{
    name: "Profile Completion",
    description: "User completes 100% of their profile information",
    status: "active"
  },
  %{
    name: "Social Media Share",
    description: "User shares content on social media",
    status: "active"
  },
  %{
    name: "Minimum Purchase Amount",
    description: "Purchase must be above a certain amount",
    status: "active"
  },
  %{
    name: "Product Review",
    description: "User submits a product review",
    status: "active"
  },
  %{
    name: "Newsletter Subscription",
    description: "User subscribes to the newsletter",
    status: "active"
  },
  %{
    name: "Mobile App Install",
    description: "User installs the mobile application",
    status: "active"
  },
  %{
    name: "Survey Completion",
    description: "User completes a customer satisfaction survey",
    status: "active"
  },
  %{
    name: "Birthday Month",
    description: "Special rewards during user's birthday month",
    status: "active"
  },
  %{
    name: "Consecutive Purchases",
    description: "User makes purchases in consecutive months",
    status: "active"
  },
  %{
    name: "Wishlist Creation",
    description: "User creates and saves a wishlist",
    status: "inactive"
  }
]

Enum.each(criteria_list, fn criterion_attrs ->
  %Criterion{}
  |> Criterion.changeset(criterion_attrs)
  |> Repo.insert!()
end)

IO.puts("Seeded #{length(criteria_list)} criteria successfully!")
