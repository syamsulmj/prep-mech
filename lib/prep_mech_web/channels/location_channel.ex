defmodule PrepMechWeb.LocationChannel do
  @moduledoc """
  Live delivery location for one order, topic `"location:<order_id>"`.

  Unlike `OrderChannel` (customer-only), this topic is joinable by EITHER the
  order's assigned shopper OR its owning customer — the shopper pushes GPS, the
  customer receives it. Points are stored in `PrepMech.LiveLocations` (ETS, not
  the DB) and broadcast to the topic. A joiner gets the current point immediately.
  """

  use PrepMechWeb, :channel

  alias PrepMech.LiveLocations
  alias PrepMech.Orders

  @impl true
  def join("location:" <> order_id, _payload, socket) do
    user_id = socket.assigns.user_id

    if Orders.get_shopper_order(user_id, order_id) || Orders.get_customer_order(user_id, order_id) do
      {:ok, %{location: LiveLocations.get(order_id)}, assign(socket, :order_id, order_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("loc", %{"lat" => lat, "lng" => lng}, socket) do
    order_id = socket.assigns.order_id
    LiveLocations.put(order_id, lat, lng)
    broadcast!(socket, "loc", %{lat: lat, lng: lng, updated_at: System.system_time(:second)})
    {:noreply, socket}
  end
end
