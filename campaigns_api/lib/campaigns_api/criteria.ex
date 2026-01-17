defmodule CampaignsApi.Criteria do
  @moduledoc """
  The Criteria context.

  This module provides functions for managing criteria and their associations with campaigns.
  """

  import Ecto.Query, warn: false
  alias CampaignsApi.Repo
  alias CampaignsApi.Criteria.Criterion
  alias CampaignsApi.Campaigns.CampaignCriterion

  @doc """
  Returns the list of criteria.

  ## Examples

      iex> list_criteria()
      [%Criterion{}, ...]

  """
  @spec list_criteria() :: [Criterion.t()]
  def list_criteria do
    Repo.all(Criterion)
  end

  @doc """
  Returns the list of active criteria.

  ## Examples

      iex> list_active_criteria()
      [%Criterion{}, ...]

  """
  @spec list_active_criteria() :: [Criterion.t()]
  def list_active_criteria do
    Criterion
    |> where([cr], cr.status == "active")
    |> Repo.all()
  end

  @doc """
  Gets a single criterion.

  Raises `Ecto.NoResultsError` if the Criterion does not exist.

  ## Examples

      iex> get_criterion!(123)
      %Criterion{}

      iex> get_criterion!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_criterion!(Ecto.UUID.t()) :: Criterion.t()
  def get_criterion!(id), do: Repo.get!(Criterion, id)

  @doc """
  Gets a single criterion by id.

  Returns `nil` if the Criterion does not exist.

  ## Examples

      iex> get_criterion(criterion_id)
      %Criterion{}

      iex> get_criterion(criterion_id)
      nil

  """
  @spec get_criterion(Ecto.UUID.t()) :: Criterion.t() | nil
  def get_criterion(id) do
    Repo.get(Criterion, id)
  end

  @doc """
  Creates a criterion.

  ## Examples

      iex> create_criterion(%{name: "Daily Login", status: "active"})
      {:ok, %Criterion{}}

      iex> create_criterion(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_criterion(map()) :: {:ok, Criterion.t()} | {:error, Ecto.Changeset.t()}
  def create_criterion(attrs \\ %{}) do
    %Criterion{}
    |> Criterion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a criterion.

  ## Examples

      iex> update_criterion(criterion, %{name: "Updated Name"})
      {:ok, %Criterion{}}

      iex> update_criterion(criterion, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_criterion(Criterion.t(), map()) ::
          {:ok, Criterion.t()} | {:error, Ecto.Changeset.t()}
  def update_criterion(%Criterion{} = criterion, attrs) do
    criterion
    |> Criterion.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a criterion.

  ## Examples

      iex> delete_criterion(criterion)
      {:ok, %Criterion{}}

      iex> delete_criterion(criterion)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_criterion(Criterion.t()) :: {:ok, Criterion.t()} | {:error, Ecto.Changeset.t()}
  def delete_criterion(%Criterion{} = criterion) do
    Repo.delete(criterion)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking criterion changes.

  ## Examples

      iex> change_criterion(criterion)
      %Ecto.Changeset{data: %Criterion{}}

  """
  @spec change_criterion(Criterion.t(), map()) :: Ecto.Changeset.t()
  def change_criterion(%Criterion{} = criterion, attrs \\ %{}) do
    Criterion.changeset(criterion, attrs)
  end

  @doc """
  Associates a criterion with a campaign.

  ## Examples

      iex> associate_criterion_to_campaign(%{campaign_id: campaign_id, criterion_id: criterion_id, reward_points_amount: 100})
      {:ok, %CampaignCriterion{}}

      iex> associate_criterion_to_campaign(%{campaign_id: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec associate_criterion_to_campaign(map()) ::
          {:ok, CampaignCriterion.t()} | {:error, Ecto.Changeset.t()}
  def associate_criterion_to_campaign(attrs \\ %{}) do
    %CampaignCriterion{}
    |> CampaignCriterion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a campaign criterion association.

  ## Examples

      iex> update_campaign_criterion(campaign_criterion, %{reward_points_amount: 200})
      {:ok, %CampaignCriterion{}}

      iex> update_campaign_criterion(campaign_criterion, %{reward_points_amount: -1})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_campaign_criterion(CampaignCriterion.t(), map()) ::
          {:ok, CampaignCriterion.t()} | {:error, Ecto.Changeset.t()}
  def update_campaign_criterion(%CampaignCriterion{} = campaign_criterion, attrs) do
    campaign_criterion
    |> CampaignCriterion.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Removes a criterion association from a campaign.

  ## Examples

      iex> remove_criterion_from_campaign(campaign_criterion)
      {:ok, %CampaignCriterion{}}

      iex> remove_criterion_from_campaign(campaign_criterion)
      {:error, %Ecto.Changeset{}}

  """
  @spec remove_criterion_from_campaign(CampaignCriterion.t()) ::
          {:ok, CampaignCriterion.t()} | {:error, Ecto.Changeset.t()}
  def remove_criterion_from_campaign(%CampaignCriterion{} = campaign_criterion) do
    Repo.delete(campaign_criterion)
  end

  @doc """
  Gets a campaign criterion association by campaign_id and criterion_id.

  ## Examples

      iex> get_campaign_criterion(campaign_id, criterion_id)
      %CampaignCriterion{}

      iex> get_campaign_criterion(campaign_id, criterion_id)
      nil

  """
  @spec get_campaign_criterion(Ecto.UUID.t(), Ecto.UUID.t()) :: CampaignCriterion.t() | nil
  def get_campaign_criterion(campaign_id, criterion_id) do
    CampaignCriterion
    |> where([cc], cc.campaign_id == ^campaign_id and cc.criterion_id == ^criterion_id)
    |> Repo.one()
  end

  @doc """
  Lists all criteria associated with a campaign.

  ## Examples

      iex> list_campaign_criteria(campaign_id)
      [%CampaignCriterion{}, ...]

  """
  @spec list_campaign_criteria(Ecto.UUID.t()) :: [CampaignCriterion.t()]
  def list_campaign_criteria(campaign_id) do
    CampaignCriterion
    |> where([cc], cc.campaign_id == ^campaign_id)
    |> preload(:criterion)
    |> Repo.all()
  end

  @doc """
  Lists all criteria associated with a campaign for a specific tenant.

  ## Examples

      iex> list_campaign_criteria_by_tenant(campaign_id, tenant)
      [%CampaignCriterion{}, ...]

  """
  @spec list_campaign_criteria_by_tenant(Ecto.UUID.t(), String.t()) :: [CampaignCriterion.t()]
  def list_campaign_criteria_by_tenant(campaign_id, tenant) do
    CampaignCriterion
    |> join(:inner, [cc], c in assoc(cc, :campaign))
    |> where([cc, c], cc.campaign_id == ^campaign_id and c.tenant == ^tenant)
    |> preload(:criterion)
    |> Repo.all()
  end

  @doc """
  Associates a criterion with a campaign after validating tenant ownership.

  ## Examples

      iex> associate_criterion_to_campaign_by_tenant(%{campaign_id: campaign_id, criterion_id: criterion_id}, tenant)
      {:ok, %CampaignCriterion{}}

      iex> associate_criterion_to_campaign_by_tenant(%{campaign_id: invalid_id}, tenant)
      {:error, :not_found}

  """
  @spec associate_criterion_to_campaign_by_tenant(map(), String.t()) ::
          {:ok, CampaignCriterion.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def associate_criterion_to_campaign_by_tenant(attrs, tenant) do
    alias CampaignsApi.Campaigns.Campaign

    campaign_id = attrs["campaign_id"]

    case Repo.get_by(Campaign, id: campaign_id, tenant: tenant) do
      nil ->
        {:error, :not_found}

      _campaign ->
        %CampaignCriterion{}
        |> CampaignCriterion.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, campaign_criterion} ->
            {:ok, Repo.preload(campaign_criterion, :criterion)}

          error ->
            error
        end
    end
  end

  @doc """
  Updates a campaign criterion association after validating tenant ownership.

  ## Examples

      iex> update_campaign_criterion_by_tenant(campaign_id, criterion_id, %{reward_points_amount: 200}, tenant)
      {:ok, %CampaignCriterion{}}

  """
  @spec update_campaign_criterion_by_tenant(Ecto.UUID.t(), Ecto.UUID.t(), map(), String.t()) ::
          {:ok, CampaignCriterion.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def update_campaign_criterion_by_tenant(campaign_id, criterion_id, attrs, tenant) do
    alias CampaignsApi.Campaigns.Campaign

    campaign_criterion =
      CampaignCriterion
      |> join(:inner, [cc], c in Campaign, on: cc.campaign_id == c.id)
      |> where(
        [cc, c],
        cc.campaign_id == ^campaign_id and cc.criterion_id == ^criterion_id and
          c.tenant == ^tenant
      )
      |> Repo.one()

    case campaign_criterion do
      nil ->
        {:error, :not_found}

      campaign_criterion ->
        campaign_criterion
        |> CampaignCriterion.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            {:ok, Repo.preload(updated, :criterion)}

          error ->
            error
        end
    end
  end

  @doc """
  Removes a criterion association from a campaign after validating tenant ownership.

  ## Examples

      iex> remove_campaign_criterion_by_tenant(campaign_id, criterion_id, tenant)
      {:ok, %CampaignCriterion{}}

  """
  @spec remove_campaign_criterion_by_tenant(Ecto.UUID.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, CampaignCriterion.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def remove_campaign_criterion_by_tenant(campaign_id, criterion_id, tenant) do
    alias CampaignsApi.Campaigns.Campaign

    campaign_criterion =
      CampaignCriterion
      |> join(:inner, [cc], c in Campaign, on: cc.campaign_id == c.id)
      |> where(
        [cc, c],
        cc.campaign_id == ^campaign_id and cc.criterion_id == ^criterion_id and
          c.tenant == ^tenant
      )
      |> Repo.one()

    case campaign_criterion do
      nil ->
        {:error, :not_found}

      campaign_criterion ->
        Repo.delete(campaign_criterion)
    end
  end
end
