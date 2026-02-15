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

alias CampaignsApi.CampaignManagement
alias CampaignsApi.Challenges
alias CampaignsApi.Repo
alias CampaignsApi.Tenants

# Clear existing data (optional - comment out if you want to keep existing data)
IO.puts("Cleaning existing data...")
Repo.delete_all(CampaignsApi.CampaignManagement.CampaignChallenge)
Repo.delete_all(CampaignsApi.CampaignManagement.Campaign)
Repo.delete_all(CampaignsApi.Challenges.Challenge)
Repo.delete_all(CampaignsApi.Tenants.Tenant)

# Create Tenants
IO.puts("Creating tenants...")

{:ok, tenant1} = Tenants.create_tenant("acme-corp")
{:ok, tenant2} = Tenants.create_tenant("tech-startup")
{:ok, tenant3} = Tenants.create_tenant("retail-chain")

IO.puts("✓ Created #{Repo.aggregate(CampaignsApi.Tenants.Tenant, :count)} tenants")

# Create Challenges (global, available to all tenants)
IO.puts("Creating challenges...")

{:ok, challenge1} =
  Challenges.create_challenge(%{
    name: "Purchase Frequency",
    description: "Rewards customers for making frequent purchases",
    metadata: %{
      "type" => "transaction",
      "category" => "engagement",
      "difficulty" => "easy"
    }
  })

{:ok, challenge2} =
  Challenges.create_challenge(%{
    name: "High Value Transaction",
    description: "Rewards customers for high-value purchases",
    metadata: %{
      "type" => "transaction",
      "category" => "revenue",
      "difficulty" => "medium"
    }
  })

{:ok, challenge3} =
  Challenges.create_challenge(%{
    name: "Loyalty Milestone",
    description: "Rewards long-term customer loyalty",
    metadata: %{
      "type" => "milestone",
      "category" => "retention",
      "difficulty" => "hard"
    }
  })

{:ok, challenge4} =
  Challenges.create_challenge(%{
    name: "Referral Program",
    description: "Rewards customers for referring new customers",
    metadata: %{
      "type" => "referral",
      "category" => "acquisition",
      "difficulty" => "medium"
    }
  })

{:ok, challenge5} =
  Challenges.create_challenge(%{
    name: "Social Media Engagement",
    description: "Rewards customers for social media interactions",
    metadata: %{
      "type" => "social",
      "category" => "engagement",
      "difficulty" => "easy"
    }
  })

IO.puts("✓ Created #{Repo.aggregate(CampaignsApi.Challenges.Challenge, :count)} challenges")

# Create Campaigns for Tenant 1 (ACME Corp)
IO.puts("Creating campaigns for ACME Corp...")

{:ok, campaign1} =
  CampaignManagement.create_campaign(tenant1.id, %{
    name: "Summer Sale 2024",
    description: "Boost summer sales with exciting rewards",
    status: :active,
    start_time: DateTime.utc_now(),
    end_time: DateTime.utc_now() |> DateTime.add(90, :day)
  })

{:ok, campaign2} =
  CampaignManagement.create_campaign(tenant1.id, %{
    name: "Black Friday Bonanza",
    description: "Massive rewards for Black Friday shoppers",
    status: :paused,
    start_time: DateTime.utc_now() |> DateTime.add(120, :day),
    end_time: DateTime.utc_now() |> DateTime.add(125, :day)
  })

{:ok, campaign3} =
  CampaignManagement.create_campaign(tenant1.id, %{
    name: "Loyalty Program Q4",
    description: "Year-end loyalty rewards program",
    status: :active,
    start_time: DateTime.utc_now(),
    end_time: DateTime.utc_now() |> DateTime.add(180, :day)
  })

# Create Campaigns for Tenant 2 (Tech Startup)
IO.puts("Creating campaigns for Tech Startup...")

{:ok, campaign4} =
  CampaignManagement.create_campaign(tenant2.id, %{
    name: "Launch Week Special",
    description: "Celebrate our product launch with rewards",
    status: :active,
    start_time: DateTime.utc_now(),
    end_time: DateTime.utc_now() |> DateTime.add(7, :day)
  })

{:ok, campaign5} =
  CampaignManagement.create_campaign(tenant2.id, %{
    name: "Early Adopter Program",
    description: "Rewards for our first 1000 customers",
    status: :active,
    start_time: DateTime.utc_now(),
    end_time: DateTime.utc_now() |> DateTime.add(365, :day)
  })

# Create Campaigns for Tenant 3 (Retail Chain)
IO.puts("Creating campaigns for Retail Chain...")

{:ok, campaign6} =
  CampaignManagement.create_campaign(tenant3.id, %{
    name: "Store Anniversary Sale",
    description: "Celebrating 10 years with amazing rewards",
    status: :active,
    start_time: DateTime.utc_now(),
    end_time: DateTime.utc_now() |> DateTime.add(30, :day)
  })

{:ok, campaign7} =
  CampaignManagement.create_campaign(tenant3.id, %{
    name: "Holiday Shopping Rewards",
    description: "Make holiday shopping more rewarding",
    status: :paused,
    start_time: DateTime.utc_now() |> DateTime.add(60, :day),
    end_time: DateTime.utc_now() |> DateTime.add(90, :day)
  })

IO.puts("✓ Created #{Repo.aggregate(CampaignsApi.CampaignManagement.Campaign, :count)} campaigns")

# Associate Challenges with Campaigns
IO.puts("Creating campaign-challenge associations...")

# ACME Corp - Summer Sale Campaign
{:ok, _cc1} =
  CampaignManagement.create_campaign_challenge(tenant1.id, campaign1.id, %{
    challenge_id: challenge1.id,
    display_name: "Shop More, Earn More",
    display_description: "Make 5 purchases this month and earn bonus points",
    evaluation_frequency: "daily",
    reward_points: 100,
    configuration: %{"min_purchases" => 5, "period_days" => 30}
  })

{:ok, _cc2} =
  CampaignManagement.create_campaign_challenge(tenant1.id, campaign1.id, %{
    challenge_id: challenge2.id,
    display_name: "Big Spender Bonus",
    display_description: "Spend over $500 and get 500 bonus points",
    evaluation_frequency: "on_event",
    reward_points: 500,
    configuration: %{"min_amount" => 500}
  })

# ACME Corp - Loyalty Program
{:ok, _cc3} =
  CampaignManagement.create_campaign_challenge(tenant1.id, campaign3.id, %{
    challenge_id: challenge3.id,
    display_name: "Loyalty Champion",
    display_description: "Reach 1 year as a customer",
    evaluation_frequency: "monthly",
    reward_points: 1000,
    configuration: %{"milestone_days" => 365}
  })

{:ok, _cc4} =
  CampaignManagement.create_campaign_challenge(tenant1.id, campaign3.id, %{
    challenge_id: challenge4.id,
    display_name: "Bring a Friend",
    display_description: "Refer a friend and both get rewards",
    evaluation_frequency: "on_event",
    reward_points: 250,
    configuration: %{"referral_bonus" => 250}
  })

# Tech Startup - Launch Week
{:ok, _cc5} =
  CampaignManagement.create_campaign_challenge(tenant2.id, campaign4.id, %{
    challenge_id: challenge1.id,
    display_name: "Launch Week Warrior",
    display_description: "Make 3 purchases during launch week",
    evaluation_frequency: "daily",
    reward_points: 300,
    configuration: %{"min_purchases" => 3, "period_days" => 7}
  })

{:ok, _cc6} =
  CampaignManagement.create_campaign_challenge(tenant2.id, campaign4.id, %{
    challenge_id: challenge5.id,
    display_name: "Social Sharer",
    display_description: "Share our launch on social media",
    evaluation_frequency: "on_event",
    reward_points: 50,
    configuration: %{"platforms" => ["twitter", "facebook", "instagram"]}
  })

# Tech Startup - Early Adopter
{:ok, _cc7} =
  CampaignManagement.create_campaign_challenge(tenant2.id, campaign5.id, %{
    challenge_id: challenge3.id,
    display_name: "Early Adopter Badge",
    display_description: "Be among our first 1000 customers",
    evaluation_frequency: "on_event",
    reward_points: 500,
    configuration: %{"max_customers" => 1000}
  })

# Retail Chain - Anniversary Sale
{:ok, _cc8} =
  CampaignManagement.create_campaign_challenge(tenant3.id, campaign6.id, %{
    challenge_id: challenge1.id,
    display_name: "Anniversary Shopper",
    display_description: "Shop 3 times during our anniversary month",
    evaluation_frequency: "weekly",
    reward_points: 200,
    configuration: %{"min_purchases" => 3, "period_days" => 30}
  })

{:ok, _cc9} =
  CampaignManagement.create_campaign_challenge(tenant3.id, campaign6.id, %{
    challenge_id: challenge2.id,
    display_name: "Anniversary VIP",
    display_description: "Spend $1000+ during anniversary sale",
    evaluation_frequency: "on_event",
    reward_points: 1000,
    configuration: %{"min_amount" => 1000}
  })

{:ok, _cc10} =
  CampaignManagement.create_campaign_challenge(tenant3.id, campaign6.id, %{
    challenge_id: challenge4.id,
    display_name: "Anniversary Ambassador",
    display_description: "Refer 3 friends during anniversary month",
    evaluation_frequency: "weekly",
    reward_points: 750,
    configuration: %{"min_referrals" => 3}
  })

IO.puts(
  "✓ Created #{Repo.aggregate(CampaignsApi.CampaignManagement.CampaignChallenge, :count)} campaign-challenge associations"
)

IO.puts("\n✅ Database seeded successfully!")
IO.puts("\nSummary:")
IO.puts("  - #{Repo.aggregate(CampaignsApi.Tenants.Tenant, :count)} tenants")
IO.puts("  - #{Repo.aggregate(CampaignsApi.Challenges.Challenge, :count)} challenges")
IO.puts("  - #{Repo.aggregate(CampaignsApi.CampaignManagement.Campaign, :count)} campaigns")

IO.puts(
  "  - #{Repo.aggregate(CampaignsApi.CampaignManagement.CampaignChallenge, :count)} campaign-challenge associations"
)

IO.puts("\nTenant IDs for testing:")
IO.puts("  - ACME Corp: #{tenant1.id}")
IO.puts("  - Tech Startup: #{tenant2.id}")
IO.puts("  - Retail Chain: #{tenant3.id}")
