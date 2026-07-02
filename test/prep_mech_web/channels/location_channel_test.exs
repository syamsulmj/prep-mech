defmodule PrepMechWeb.LocationChannelTest do
  # Not async: join/3 queries the DB; ETS is global.
  use PrepMechWeb.ChannelCase

  alias PrepMech.LiveLocations
  alias PrepMechWeb.LocationChannel
  alias PrepMechWeb.UserSocket

  defp connect_as(user) do
    token = Phoenix.Token.sign(PrepMechWeb.Endpoint, "user socket", user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    socket
  end

  test "the assigned shopper can join and gets the current point on join" do
    shopper = insert(:user, role: :shopper)
    order = insert(:order, shopper: shopper, status: :on_delivery)
    LiveLocations.put(order.id, 3.16, 101.71)

    assert {:ok, %{location: %{lat: 3.16, lng: 101.71}}, _socket} =
             shopper
             |> connect_as()
             |> subscribe_and_join(LocationChannel, "location:#{order.id}")
  end

  test "the owning customer can join; unknown location replies nil" do
    customer = insert(:user, role: :customer)
    order = insert(:order, customer: customer, status: :on_delivery)

    assert {:ok, %{location: nil}, _socket} =
             customer
             |> connect_as()
             |> subscribe_and_join(LocationChannel, "location:#{order.id}")
  end

  test "a stranger is refused" do
    order = insert(:order, shopper: insert(:user, role: :shopper))
    stranger = insert(:user, role: :customer)

    assert {:error, %{reason: "unauthorized"}} =
             stranger
             |> connect_as()
             |> subscribe_and_join(LocationChannel, "location:#{order.id}")
  end

  test "a loc push writes ETS and broadcasts to subscribers" do
    shopper = insert(:user, role: :shopper)
    order = insert(:order, shopper: shopper, status: :on_delivery)

    {:ok, _reply, socket} =
      shopper |> connect_as() |> subscribe_and_join(LocationChannel, "location:#{order.id}")

    push(socket, "loc", %{"lat" => 3.20, "lng" => 101.60})

    assert_broadcast "loc", %{lat: 3.20, lng: 101.60, updated_at: _ts}
    assert %{lat: 3.20, lng: 101.60} = LiveLocations.get(order.id)
  end
end
