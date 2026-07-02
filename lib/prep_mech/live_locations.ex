defmodule PrepMech.LiveLocations do
  @moduledoc """
  Ephemeral store for shoppers' live delivery coordinates.

  Backed by a single public ETS table owned by this GenServer. Location is
  high-frequency, disposable telemetry, so it is deliberately NOT persisted to
  the database — it lives here and is broadcast over a channel (see
  `PrepMechWeb.LocationChannel`). It is lost on restart, which is acceptable:
  the next GPS ping refreshes it.
  """

  use GenServer

  @table :prep_mech_live_locations
  @default_max_age 30

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @doc "Stores the latest point for an order, stamped with the current time."
  def put(order_id, lat, lng) do
    point = %{lat: lat, lng: lng, updated_at: System.system_time(:second)}
    :ets.insert(@table, {to_string(order_id), point})
    :ok
  end

  @doc "Returns the latest point for an order, or nil if none is known."
  def get(order_id) do
    case :ets.lookup(@table, to_string(order_id)) do
      [{_id, point}] -> point
      [] -> nil
    end
  end

  @doc "True if a point is missing or older than `max_age` seconds."
  def stale?(location, max_age \\ @default_max_age)
  def stale?(nil, _max_age), do: true

  def stale?(%{updated_at: updated_at}, max_age) do
    System.system_time(:second) - updated_at > max_age
  end
end
