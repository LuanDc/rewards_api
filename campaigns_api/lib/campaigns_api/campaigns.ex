defmodule CampaignsApi.Campaigns do
  @moduledoc """
  The Campaigns context.

  This module provides functions for managing campaigns.
  """

  import Ecto.Query, warn: false
  alias CampaignsApi.Repo
  alias CampaignsApi.Campaigns.Campaign

  @doc """
  Returns the list of campaigns.

  ## Examples

      iex> list_campaigns()
      [%Campaign{}, ...]

  """
  @spec list_campaigns() :: [Campaign.t()]
  def list_campaigns do
    Repo.all(Campaign)
  end

  @doc """
  Returns the list of campaigns for a specific tenant.

  ## Examples

      iex> list_campaigns_by_tenant("tenant-123")
      [%Campaign{}, ...]

  """
  @spec list_campaigns_by_tenant(String.t()) :: [Campaign.t()]
  def list_campaigns_by_tenant(tenant) do
    Campaign
    |> where([c], c.tenant == ^tenant)
    |> Repo.all()
  end

  @doc """
  Gets a single campaign.

  Raises `Ecto.NoResultsError` if the Campaign does not exist.

  ## Examples

      iex> get_campaign!(123)
      %Campaign{}

      iex> get_campaign!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_campaign!(Ecto.UUID.t()) :: Campaign.t()
  def get_campaign!(id), do: Repo.get!(Campaign, id)

  @doc """
  Gets a single campaign by id and tenant.

  Returns `nil` if the Campaign does not exist.

  ## Examples

      iex> get_campaign_by_tenant(campaign_id, "tenant-123")
      %Campaign{}

      iex> get_campaign_by_tenant(campaign_id, "tenant-123")
      nil

  """
  @spec get_campaign_by_tenant(Ecto.UUID.t(), String.t()) :: Campaign.t() | nil
  def get_campaign_by_tenant(id, tenant) do
    Campaign
    |> where([c], c.id == ^id and c.tenant == ^tenant)
    |> Repo.one()
  end

  @doc """
  Creates a campaign.

  ## Examples

      iex> create_campaign(%{name: "Summer Campaign", tenant: "tenant-123"})
      {:ok, %Campaign{}}

      iex> create_campaign(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_campaign(map()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def create_campaign(attrs \\ %{}) do
    %Campaign{}
    |> Campaign.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a campaign.

  ## Examples

      iex> update_campaign(campaign, %{name: "Updated Name"})
      {:ok, %Campaign{}}

      iex> update_campaign(campaign, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_campaign(Campaign.t(), map()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def update_campaign(%Campaign{} = campaign, attrs) do
    campaign
    |> Campaign.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a campaign.

  ## Examples

      iex> delete_campaign(campaign)
      {:ok, %Campaign{}}

      iex> delete_campaign(campaign)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_campaign(Campaign.t()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def delete_campaign(%Campaign{} = campaign) do
    Repo.delete(campaign)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking campaign changes.

  ## Examples

      iex> change_campaign(campaign)
      %Ecto.Changeset{data: %Campaign{}}

  """
  @spec change_campaign(Campaign.t(), map()) :: Ecto.Changeset.t()
  def change_campaign(%Campaign{} = campaign, attrs \\ %{}) do
    Campaign.changeset(campaign, attrs)
  end

  @doc """
  Starts a campaign by setting the started_at timestamp and status to active.

  ## Examples

      iex> start_campaign(campaign)
      {:ok, %Campaign{status: :active}}

  """
  @spec start_campaign(Campaign.t()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def start_campaign(%Campaign{} = campaign) do
    update_campaign(campaign, %{
      started_at: DateTime.utc_now(),
      status: :active
    })
  end

  @doc """
  Finishes a campaign by setting the finished_at timestamp and status to completed.

  ## Examples

      iex> finish_campaign(campaign)
      {:ok, %Campaign{status: :completed}}

  """
  @spec finish_campaign(Campaign.t()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def finish_campaign(%Campaign{} = campaign) do
    update_campaign(campaign, %{
      finished_at: DateTime.utc_now(),
      status: :completed
    })
  end
end
