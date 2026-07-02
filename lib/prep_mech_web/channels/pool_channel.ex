defmodule PrepMechWeb.PoolChannel do
  @moduledoc """
  Relays pool domain events to connected shoppers in realtime.

  On join, the channel subscribes to the `Orders` pool events. When the domain
  publishes `{:order_created, order}` or `{:order_claimed, id}`, each connected
  shopper's channel process pushes a small payload to its browser, which adds or
  removes the order card. The atomic claim in `Orders` guarantees a single
  winner; this just keeps everyone else's pool current without a refresh.
  """

  use PrepMechWeb, :channel

  alias PrepMech.OrderEvents
  alias PrepMechWeb.CoreComponents

  @impl true
  def join("orders:pool", _payload, socket) do
    OrderEvents.subscribe_to_pool()
    {:ok, socket}
  end

  @impl true
  def handle_info({:order_created, order}, socket) do
    push(socket, "order_created", %{
      id: order.id,
      count: length(order.line_items),
      summary: CoreComponents.item_summary(order.line_items),
      delivery_address: order.delivery_address
    })

    {:noreply, socket}
  end

  def handle_info({:order_claimed, order_id}, socket) do
    push(socket, "order_claimed", %{id: order_id})
    {:noreply, socket}
  end
end
