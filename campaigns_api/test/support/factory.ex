defmodule CampaignsApi.Factory do
  @moduledoc """
  Factory module for generating test data.

  This module provides factory functions to create test data for your application.
  Uses ExMachina-style syntax for creating and inserting records.

  ## Examples

      # Create a struct (not inserted into the database)
      user = build(:user)

      # Create and insert a struct into the database
      user = insert(:user)

      # Override specific attributes
      user = build(:user, name: "Custom Name")

      # Create multiple records
      users = insert_list(3, :user)

  """

  alias CampaignsApi.Repo

  @doc """
  Builds a struct without inserting it into the database.

  ## Examples

      iex> build(:user)
      %User{name: "User 1", email: "user1@example.com"}

      iex> build(:user, name: "Custom Name")
      %User{name: "Custom Name", email: "user2@example.com"}

  """
  def build(factory_name, attrs \\ %{})

  def build(:campaign, attrs) do
    %CampaignsApi.Campaigns.Campaign{
      name: "Campaign #{System.unique_integer([:positive])}",
      tenant: "tenant-#{System.unique_integer([:positive])}",
      status: :not_started
    }
    |> merge_attrs(attrs)
  end

  def build(:criterion, attrs) do
    %CampaignsApi.Criteria.Criterion{
      id: Uniq.UUID.uuid7(),
      name: "Criterion #{System.unique_integer([:positive])}",
      status: "active",
      description: "Description for criterion #{System.unique_integer([:positive])}"
    }
    |> merge_attrs(attrs)
  end

  def build(:campaign_criterion, attrs) do
    %CampaignsApi.Campaigns.CampaignCriterion{
      id: Uniq.UUID.uuid7(),
      periodicity: "0 0 * * *",
      status: "active",
      reward_points_amount: 100
    }
    |> merge_attrs(attrs)
  end

  @doc """
  Builds and inserts a struct into the database.

  ## Examples

      iex> insert(:user)
      %User{id: 1, name: "User 1", email: "user1@example.com"}

      iex> insert(:user, name: "Custom Name")
      %User{id: 2, name: "Custom Name", email: "user2@example.com"}

  """
  def insert(factory_name, attrs \\ %{}) do
    factory_name
    |> build(attrs)
    |> Repo.insert!()
  end

  @doc """
  Builds a list of structs without inserting them into the database.

  ## Examples

      iex> build_list(3, :user)
      [%User{...}, %User{...}, %User{...}]

  """
  def build_list(count, factory_name, attrs \\ %{}) do
    Enum.map(1..count, fn _ -> build(factory_name, attrs) end)
  end

  @doc """
  Builds and inserts a list of structs into the database.

  ## Examples

      iex> insert_list(3, :user)
      [%User{id: 1, ...}, %User{id: 2, ...}, %User{id: 3, ...}]

  """
  def insert_list(count, factory_name, attrs \\ %{}) do
    Enum.map(1..count, fn _ -> insert(factory_name, attrs) end)
  end

  @doc """
  Builds a params map (useful for controller tests).

  ## Examples

      iex> params_for(:user)
      %{name: "User 1", email: "user1@example.com"}

  """
  def params_for(factory_name, attrs \\ %{}) do
    factory_name
    |> build(attrs)
    |> struct_to_map()
  end

  # Private helpers

  defp merge_attrs(struct, attrs) do
    struct
    |> Map.from_struct()
    |> Map.merge(stringify_keys(attrs))
    |> then(&struct(struct.__struct__, &1))
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
    end)
  end

  defp stringify_keys(list) when is_list(list) do
    list
    |> Enum.into(%{})
    |> stringify_keys()
  end

  defp struct_to_map(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :id, :inserted_at, :updated_at])
  end
end
