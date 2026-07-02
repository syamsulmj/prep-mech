defmodule PrepMech.OrderEvents do
  @moduledoc """
  The realtime event bus for orders — a thin, explicit wrapper over `Phoenix.PubSub`.

  It keeps topic names and message shapes in one place so the `PrepMech.Orders`
  context can publish domain events without touching PubSub, and web channels can
  subscribe without hardcoding topic strings.

  Topics and the messages delivered on them:

    * `"orders:pool"`   — `{:order_created, %Order{}}` and `{:order_claimed, order_id}`
    * `"order:<id>"`    — `{:order_updated, _}` on any status or line-item change
    * `"customer:<id>"` — `{:order_updated, %Order{}}` for that customer's order list
  """

  alias PrepMech.LineItem
  alias PrepMech.Order

  @pubsub PrepMech.PubSub
  @pool_topic "orders:pool"

  ## Subscriptions

  @doc "Subscribes the caller to the open-pool feed (new + claimed orders)."
  def subscribe_to_pool(), do: Phoenix.PubSub.subscribe(@pubsub, @pool_topic)

  @doc "Subscribes the caller to a single order's updates."
  def subscribe_to_order(order_id), do: Phoenix.PubSub.subscribe(@pubsub, order_topic(order_id))

  @doc "Subscribes the caller to all of a customer's order updates."
  def subscribe_to_customer(customer_id),
    do: Phoenix.PubSub.subscribe(@pubsub, customer_topic(customer_id))

  ## Broadcasts

  @doc "A customer placed a new order — announce it to the pool."
  def order_created(%Order{} = order) do
    Phoenix.PubSub.broadcast(@pubsub, @pool_topic, {:order_created, order})
  end

  @doc "A shopper claimed an order — drop it from the pool and update watchers."
  def order_claimed(%Order{} = order) do
    Phoenix.PubSub.broadcast(@pubsub, @pool_topic, {:order_claimed, order.id})
    order_updated(order)
  end

  @doc "An order's status changed — notify its tracking view and its customer's list."
  def order_updated(%Order{} = order) do
    Phoenix.PubSub.broadcast(@pubsub, order_topic(order.id), {:order_updated, order})
    Phoenix.PubSub.broadcast(@pubsub, customer_topic(order.customer_id), {:order_updated, order})
  end

  @doc "A line item was resolved — notify the order's tracking view."
  def item_updated(%LineItem{} = item) do
    Phoenix.PubSub.broadcast(@pubsub, order_topic(item.order_id), {:order_updated, item})
  end

  ## Topics

  defp order_topic(order_id), do: "order:#{order_id}"
  defp customer_topic(customer_id), do: "customer:#{customer_id}"
end
