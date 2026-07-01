defmodule PrepMech.Orders do
  @moduledoc """
  Business logic for the order lifecycle.

  Customers create orders; shoppers claim them from a shared pool and drive
  them forward through a fixed status sequence:

      pending -> accepted -> shopping -> on_delivery -> delivered

  Two transitions carry extra rules that live here, not in the web layer:

    * **Claiming** (`pending -> accepted`) is atomic — the first shopper to
      claim a pending order wins; a losing claim returns `{:error, :already_claimed}`.
    * **Going out for delivery** (`shopping -> on_delivery`) is gated: every
      line item must be resolved (`is_found` set) first.
  """

  import Ecto.Query

  alias PrepMech.LineItem
  alias PrepMech.Order
  alias PrepMech.Repo

  @doc """
  Creates a pending order with its line items in a single insert.

  Returns `{:ok, order}` or `{:error, changeset}`.
  """
  def create_order(attrs) do
    %Order{}
    |> Order.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Gets an order by id. Raises if it does not exist."
  def get_order!(id), do: Repo.get!(Order, id)

  @doc "Gets an order by id, or `nil`."
  def get_order(id), do: Repo.get(Order, id)

  @doc """
  Lists the open pool: every `:pending` order, oldest first, with line items.
  """
  def list_pool() do
    Order
    |> where([o], o.status == :pending)
    |> order_by([o], asc: o.inserted_at)
    |> preload(:line_items)
    |> Repo.all()
  end

  @doc "Lists a customer's orders, newest first."
  def list_for_customer(customer_id) do
    Order
    |> where([o], o.customer_id == ^customer_id)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
  end

  @doc "Lists the orders a shopper has claimed, newest first."
  def list_for_shopper(shopper_id) do
    Order
    |> where([o], o.shopper_id == ^shopper_id)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
  end

  @doc """
  Atomically claims a pending order for a shopper.

  The `where status == :pending` guard makes this race-safe: the database
  serializes concurrent claims, so exactly one `update_all` matches a row.

  Returns `:ok`, or `{:error, :already_claimed}` if the order was already
  taken (or never pending).
  """
  def claim_order(order_id, shopper_id) do
    {count, _} =
      Order
      |> where([o], o.id == ^order_id and o.status == :pending)
      |> Repo.update_all(
        set: [status: :accepted, shopper_id: shopper_id, accepted_at: now(), updated_at: now()]
      )

    claim_result(count)
  end

  defp claim_result(1), do: :ok
  defp claim_result(0), do: {:error, :already_claimed}

  @doc """
  Advances an order one step along the lifecycle.

  Enforces forward-only, single-step transitions and the "all items resolved"
  gate before delivery. Returns `{:ok, order}`, `{:error, :invalid_transition}`,
  or `{:error, :unresolved_items}`.
  """
  def advance_status(%Order{status: from} = order, target) do
    with :ok <- validate_transition(from, target),
         :ok <- validate_gate(order, from, target) do
      order
      |> Order.status_changeset(transition_attrs(target))
      |> Repo.update()
    end
  end

  defp validate_transition(from, target) do
    if next_status(from) == target, do: :ok, else: {:error, :invalid_transition}
  end

  defp next_status(:accepted), do: :shopping
  defp next_status(:shopping), do: :on_delivery
  defp next_status(:on_delivery), do: :delivered
  defp next_status(_), do: nil

  defp validate_gate(order, :shopping, :on_delivery) do
    if all_items_resolved?(order), do: :ok, else: {:error, :unresolved_items}
  end

  defp validate_gate(_order, _from, _target), do: :ok

  defp transition_attrs(:delivered), do: %{status: :delivered, delivered_at: now()}
  defp transition_attrs(target), do: %{status: target}

  defp all_items_resolved?(%Order{id: id}) do
    unresolved =
      LineItem
      |> where([l], l.order_id == ^id and l.pickup_status == :pending)
      |> Repo.aggregate(:count)

    unresolved == 0
  end

  @doc """
  Resolves a line item's pickup status to `:picked` or `:unavailable`.
  """
  def set_item_pickup_status(item_id, status) when status in [:picked, :unavailable] do
    LineItem
    |> Repo.get!(item_id)
    |> LineItem.pickup_changeset(status)
    |> Repo.update()
  end

  # Helpers

  defp now(), do: DateTime.truncate(DateTime.utc_now(), :second)
end
