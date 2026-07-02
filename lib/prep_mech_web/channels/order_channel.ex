defmodule PrepMechWeb.OrderChannel do
  @moduledoc """
  Realtime order updates for customers.

  Two topics:

    * `"order:<id>"`      — a single order's tracking view. Only the customer who
      owns the order may join.
    * `"customer:<id>"`   — a customer's whole order list. Only that customer may join.

  On any status or item change the domain broadcasts `{:order_updated, _}`; the
  channel pushes a bare `"updated"` and the browser re-fetches + swaps its live
  region, so the rendered stepper / status / checklist always come from the server.
  """

  use PrepMechWeb, :channel

  alias PrepMech.OrderEvents
  alias PrepMech.Orders

  @impl true
  def join("order:" <> order_id, _payload, socket) do
    if Orders.get_customer_order(socket.assigns.user_id, order_id) do
      OrderEvents.subscribe_to_order(order_id)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("customer:" <> customer_id, _payload, socket) do
    if to_string(socket.assigns.user_id) == customer_id do
      OrderEvents.subscribe_to_customer(customer_id)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:order_updated, _payload}, socket) do
    push(socket, "updated", %{})
    {:noreply, socket}
  end
end
