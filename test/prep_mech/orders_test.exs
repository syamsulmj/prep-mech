defmodule PrepMech.OrdersTest do
  use PrepMech.DataCase, async: true

  alias PrepMech.Order
  alias PrepMech.Orders

  describe "create_order/1" do
    test "creates a pending order with its line items" do
      customer = insert(:user, role: :customer)

      attrs = %{
        customer_id: customer.id,
        delivery_address: "12 Jalan Test",
        notes: "Leave at the door",
        line_items: [
          %{name: "Milk", quantity: 2},
          %{name: "Bread", quantity: 1}
        ]
      }

      assert {:ok, %Order{} = order} = Orders.create_order(attrs)
      assert order.status == :pending
      assert order.customer_id == customer.id
      assert is_nil(order.shopper_id)
      assert length(order.line_items) == 2
      assert Enum.all?(order.line_items, &(&1.pickup_status == :pending))
    end

    test "requires at least one line item" do
      customer = insert(:user, role: :customer)
      attrs = %{customer_id: customer.id, delivery_address: "12 Jalan Test", line_items: []}

      assert {:error, changeset} = Orders.create_order(attrs)
      refute changeset.valid?
    end

    test "requires a delivery address" do
      customer = insert(:user, role: :customer)
      attrs = %{customer_id: customer.id, line_items: [%{name: "Milk", quantity: 1}]}

      assert {:error, changeset} = Orders.create_order(attrs)
      assert "can't be blank" in errors_on(changeset).delivery_address
    end

    test "rejects a line item with a non-positive quantity" do
      customer = insert(:user, role: :customer)

      attrs = %{
        customer_id: customer.id,
        delivery_address: "12 Jalan Test",
        line_items: [%{name: "Milk", quantity: 0}]
      }

      assert {:error, _changeset} = Orders.create_order(attrs)
    end
  end

  describe "list_pool/0" do
    test "returns only pending orders" do
      pending = insert(:order, status: :pending)
      _accepted = insert(:order, status: :accepted)
      _delivered = insert(:order, status: :delivered)

      ids = Orders.list_pool() |> Enum.map(& &1.id)
      assert ids == [pending.id]
    end
  end

  describe "list_for_customer/1 and list_for_shopper/1" do
    test "list_for_customer returns only that customer's orders" do
      c1 = insert(:user, role: :customer)
      c2 = insert(:user, role: :customer)
      mine = insert(:order, customer: c1)
      _theirs = insert(:order, customer: c2)

      ids = Orders.list_for_customer(c1.id) |> Enum.map(& &1.id)
      assert ids == [mine.id]
    end

    test "list_for_shopper returns only that shopper's claimed orders" do
      shopper = insert(:user, role: :shopper)
      mine = insert(:order, shopper: shopper, status: :accepted)
      _unclaimed = insert(:order, status: :pending)

      ids = Orders.list_for_shopper(shopper.id) |> Enum.map(& &1.id)
      assert ids == [mine.id]
    end
  end

  describe "claim_order/2" do
    test "the first shopper to claim a pending order wins" do
      order = insert(:order, status: :pending)
      shopper = insert(:user, role: :shopper)

      assert :ok = Orders.claim_order(order.id, shopper.id)

      claimed = Orders.get_order!(order.id)
      assert claimed.status == :accepted
      assert claimed.shopper_id == shopper.id
      assert claimed.accepted_at
    end

    test "a second claim on an already-claimed order is rejected" do
      order = insert(:order, status: :pending)
      first = insert(:user, role: :shopper)
      second = insert(:user, role: :shopper)

      assert :ok = Orders.claim_order(order.id, first.id)
      assert {:error, :already_claimed} = Orders.claim_order(order.id, second.id)

      assert Orders.get_order!(order.id).shopper_id == first.id
    end

    test "claiming a non-pending order is rejected" do
      order = insert(:order, status: :accepted)
      shopper = insert(:user, role: :shopper)

      assert {:error, :already_claimed} = Orders.claim_order(order.id, shopper.id)
    end
  end

  describe "advance_status/2" do
    test "moves accepted -> shopping" do
      order = insert(:order, status: :accepted)
      assert {:ok, updated} = Orders.advance_status(order, :shopping)
      assert updated.status == :shopping
    end

    test "blocks shopping -> on_delivery while any item is unresolved" do
      order =
        insert(:order,
          status: :shopping,
          line_items: [build(:line_item, pickup_status: :pending)]
        )

      assert {:error, :unresolved_items} = Orders.advance_status(order, :on_delivery)
      assert Orders.get_order!(order.id).status == :shopping
    end

    test "allows shopping -> on_delivery once every item is resolved" do
      order =
        insert(:order,
          status: :shopping,
          line_items: [
            build(:line_item, pickup_status: :picked),
            build(:line_item, pickup_status: :unavailable)
          ]
        )

      assert {:ok, updated} = Orders.advance_status(order, :on_delivery)
      assert updated.status == :on_delivery
    end

    test "moves on_delivery -> delivered and stamps delivered_at" do
      order = insert(:order, status: :on_delivery)
      assert {:ok, updated} = Orders.advance_status(order, :delivered)
      assert updated.status == :delivered
      assert updated.delivered_at
    end

    test "rejects a transition that skips a step" do
      order = insert(:order, status: :accepted)
      assert {:error, :invalid_transition} = Orders.advance_status(order, :delivered)
    end
  end

  describe "set_item_pickup_status/2" do
    test "marks an item as picked" do
      order = insert(:order, line_items: [build(:line_item, pickup_status: :pending)])
      [item] = order.line_items

      assert {:ok, updated} = Orders.set_item_pickup_status(item.id, :picked)
      assert updated.pickup_status == :picked
    end

    test "marks an item as unavailable" do
      order = insert(:order, line_items: [build(:line_item, pickup_status: :pending)])
      [item] = order.line_items

      assert {:ok, updated} = Orders.set_item_pickup_status(item.id, :unavailable)
      assert updated.pickup_status == :unavailable
    end
  end
end
