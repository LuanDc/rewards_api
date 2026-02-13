defmodule CampaignsApi.CampaignManagement do
  @moduledoc """
  The CampaignManagement context manages campaign operations with tenant isolation.

  All operations require tenant_id parameter to ensure data isolation between tenants.
  """

  import Ecto.Query
  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  @type tenant_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type attrs :: map()
  @type pagination_opts :: keyword()
  @type pagination_result :: %{
          data: [Campaign.t()],
          next_cursor: DateTime.t() | nil,
          has_more: boolean()
        }

  @doc """
  Lists campaigns for a specific tenant with cursor-based pagination.

  Automatically filters campaigns by tenant_id and orders by inserted_at descending.

  ## Parameters

    - tenant_id: The tenant ID to filter campaigns
    - opts: Pagination options (limit, cursor, cursor_field, order)

  ## Options

    - `:limit` - Number of records to return (default: 50, max: 100)
    - `:cursor` - Cursor value (datetime) to paginate from
    - `:cursor_field` - Field to use for cursor (default: :inserted_at)
    - `:order` - Sort order, :desc or :asc (default: :desc)

  ## Returns

  %{
    data: [%Campaign{}],
    next_cursor: datetime | nil,
    has_more: boolean
  }

  ## Examples

      iex> list_campaigns("tenant-123")
      %{data: [%Campaign{}, ...], next_cursor: ~U[2024-01-01 12:00:00Z], has_more: true}

      iex> list_campaigns("tenant-123", limit: 10, cursor: ~U[2024-01-01 12:00:00Z])
      %{data: [%Campaign{}, ...], next_cursor: nil, has_more: false}

  """
  @spec list_campaigns(tenant_id(), pagination_opts()) :: pagination_result()
  def list_campaigns(tenant_id, opts \\ []) do
    query =
      from c in Campaign,
        where: c.tenant_id == ^tenant_id

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Gets a single campaign by ID for a specific tenant.

  Returns nil if the campaign is not found or belongs to a different tenant.
  This ensures tenant data isolation - tenants can only access their own campaigns.

  ## Parameters

    - tenant_id: The tenant ID to filter by
    - campaign_id: The campaign ID to retrieve

  ## Returns

    - %Campaign{} if found and belongs to the tenant
    - nil if not found or belongs to different tenant

  ## Examples

      iex> get_campaign("tenant-123", "campaign-uuid")
      %Campaign{id: "campaign-uuid", tenant_id: "tenant-123", ...}

      iex> get_campaign("tenant-123", "non-existent-id")
      nil

      iex> get_campaign("tenant-123", "other-tenant-campaign-id")
      nil

  """
  @spec get_campaign(tenant_id(), campaign_id()) :: Campaign.t() | nil
  def get_campaign(tenant_id, campaign_id) do
    Repo.get_by(Campaign, id: campaign_id, tenant_id: tenant_id)
  end

  @doc """
  Creates a new campaign for a specific tenant.

  Automatically associates the campaign with the provided tenant_id and generates
  a UUID for the campaign id. Sets default status to "active" if not provided.

  ## Parameters

    - tenant_id: The tenant ID to associate the campaign with
    - attrs: Map of campaign attributes (name, description, start_time, end_time, status)

  ## Required Fields

    - name: String with minimum 3 characters

  ## Optional Fields

    - description: String
    - start_time: UTC datetime in ISO8601 format
    - end_time: UTC datetime in ISO8601 format (must be after start_time if both provided)
    - status: :active or :paused (defaults to :active)

  ## Returns

    - {:ok, %Campaign{}} on success
    - {:error, %Ecto.Changeset{}} on validation failure

  ## Examples

      iex> create_campaign("tenant-123", %{name: "Summer Sale"})
      {:ok, %Campaign{id: "...", tenant_id: "tenant-123", name: "Summer Sale", status: :active}}

      iex> create_campaign("tenant-123", %{name: "ab"})
      {:error, %Ecto.Changeset{}}

      iex> create_campaign("tenant-123", %{name: "Campaign", start_time: ~U[2024-02-01 00:00:00Z], end_time: ~U[2024-01-01 00:00:00Z]})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_campaign(tenant_id(), attrs()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def create_campaign(tenant_id, attrs) do
    %Campaign{}
    |> Campaign.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  @doc """
  Updates an existing campaign for a specific tenant.

  Only campaigns belonging to the specified tenant can be updated, ensuring
  tenant data isolation. Allows updating name, description, start_time, end_time,
  and status fields.

  ## Parameters

    - tenant_id: The tenant ID that owns the campaign
    - campaign_id: The campaign ID to update
    - attrs: Map of campaign attributes to update

  ## Updatable Fields

    - name: String with minimum 3 characters
    - description: String
    - start_time: UTC datetime in ISO8601 format
    - end_time: UTC datetime in ISO8601 format (must be after start_time if both provided)
    - status: :active or :paused

  ## Returns

    - {:ok, %Campaign{}} on success
    - {:error, :not_found} if campaign not found or belongs to different tenant
    - {:error, %Ecto.Changeset{}} on validation failure

  ## Examples

      iex> update_campaign("tenant-123", "campaign-uuid", %{name: "Updated Name"})
      {:ok, %Campaign{id: "campaign-uuid", name: "Updated Name", ...}}

      iex> update_campaign("tenant-123", "non-existent-id", %{name: "New Name"})
      {:error, :not_found}

      iex> update_campaign("tenant-123", "campaign-uuid", %{name: "ab"})
      {:error, %Ecto.Changeset{}}

      iex> update_campaign("tenant-123", "other-tenant-campaign", %{name: "New Name"})
      {:error, :not_found}

  """
  @spec update_campaign(tenant_id(), campaign_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign(tenant_id, campaign_id, attrs) do
    case get_campaign(tenant_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        campaign
        |> Campaign.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a campaign for a specific tenant (hard delete).

  Only campaigns belonging to the specified tenant can be deleted, ensuring
  tenant data isolation. The campaign is permanently removed from the database.

  ## Parameters

    - tenant_id: The tenant ID that owns the campaign
    - campaign_id: The campaign ID to delete

  ## Returns

    - {:ok, %Campaign{}} on successful deletion
    - {:error, :not_found} if campaign not found or belongs to different tenant

  ## Examples

      iex> delete_campaign("tenant-123", "campaign-uuid")
      {:ok, %Campaign{id: "campaign-uuid", ...}}

      iex> delete_campaign("tenant-123", "non-existent-id")
      {:error, :not_found}

      iex> delete_campaign("tenant-123", "other-tenant-campaign")
      {:error, :not_found}

  """
  @spec delete_campaign(tenant_id(), campaign_id()) :: {:ok, Campaign.t()} | {:error, :not_found}
  def delete_campaign(tenant_id, campaign_id) do
    case get_campaign(tenant_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        Repo.delete(campaign)
    end
  end
end
