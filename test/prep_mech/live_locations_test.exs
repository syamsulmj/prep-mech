defmodule PrepMech.LiveLocationsTest do
  # ETS is global (not sandboxed); use unique keys and run serially.
  use ExUnit.Case, async: false

  alias PrepMech.LiveLocations

  test "put then get round-trips the latest point" do
    :ok = LiveLocations.put("order-1001", 3.1390, 101.6869)
    assert %{lat: 3.1390, lng: 101.6869, updated_at: ts} = LiveLocations.get("order-1001")
    assert is_integer(ts)
  end

  test "put overwrites with the newest point" do
    LiveLocations.put("order-1002", 1.0, 1.0)
    LiveLocations.put("order-1002", 2.0, 2.0)
    assert %{lat: 2.0, lng: 2.0} = LiveLocations.get("order-1002")
  end

  test "get returns nil for an unknown order" do
    assert LiveLocations.get("order-does-not-exist") == nil
  end

  test "accepts integer order ids (stringified internally)" do
    LiveLocations.put(1003, 5.0, 6.0)
    assert %{lat: 5.0, lng: 6.0} = LiveLocations.get(1003)
    assert %{lat: 5.0, lng: 6.0} = LiveLocations.get("1003")
  end

  test "stale?/2 is false for a fresh point and true for an old one" do
    fresh = %{lat: 0.0, lng: 0.0, updated_at: System.system_time(:second)}
    old = %{lat: 0.0, lng: 0.0, updated_at: System.system_time(:second) - 120}
    refute LiveLocations.stale?(fresh, 30)
    assert LiveLocations.stale?(old, 30)
    assert LiveLocations.stale?(nil)
  end
end
