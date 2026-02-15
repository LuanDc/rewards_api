defmodule CampaignsApiWeb.Router do
  use CampaignsApiWeb, :router
  use PhoenixSwagger

  def swagger_info do
    %{
      info: %{
        version: "1.0.0",
        title: "Campaign Management API",
        description: "Multi-tenant Campaign Management API with JWT authentication",
        contact: %{
          name: "API Support",
          email: "support@example.com"
        }
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          description: "JWT Bearer token. Format: Bearer <token>",
          in: "header"
        }
      },
      security: [
        %{Bearer: []}
      ],
      basePath: "/api"
    }
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CampaignsApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug CampaignsApiWeb.Plugs.RequireAuth
    plug CampaignsApiWeb.Plugs.AssignTenant
  end

  scope "/", CampaignsApiWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :campaigns_api,
      swagger_file: "swagger.json"
  end

  scope "/api", CampaignsApiWeb do
    pipe_through [:api, :authenticated]

    resources "/campaigns", CampaignController, except: [:new, :edit] do
      resources "/challenges", CampaignChallengeController, except: [:new, :edit]
    end

    resources "/challenges", ChallengeController, only: [:index, :show]
  end

  if Application.compile_env(:campaigns_api, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CampaignsApiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
