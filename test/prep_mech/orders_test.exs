defmodule PrepMech.OrdersTest do
  use PrepMech.DataCase, async: true

  alias PrepMech.Order
  alias PrepMech.OrderEvents
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

  describe "change_order/1" do
    test "returns a changeset for a new order" do
      assert %Ecto.Changeset{} = Orders.change_order()
    end
  end

  describe "get_customer_order/2" do
    test "returns the customer's own order with line items preloaded" do
      customer = insert(:user, role: :customer)
      order = insert(:order, customer: customer, line_items: [build(:line_item, name: "Milk")])

      found = Orders.get_customer_order(customer.id, order.id)
      assert found.id == order.id
      assert [%{name: "Milk"}] = found.line_items
    end

    test "returns nil for another customer's order" do
      c1 = insert(:user, role: :customer)
      c2 = insert(:user, role: :customer)
      order = insert(:order, customer: c1)

      assert Orders.get_customer_order(c2.id, order.id) == nil
    end
  end

  describe "advance_to_next_status/1" do
    test "advances an accepted order to shopping" do
      order = insert(:order, status: :accepted)
      assert {:ok, updated} = Orders.advance_to_next_status(order)
      assert updated.status == :shopping
    end

    test "applies the resolved-items gate on shopping -> on_delivery" do
      order =
        insert(:order,
          status: :shopping,
          line_items: [build(:line_item, pickup_status: :pending)]
        )

      assert {:error, :unresolved_items} = Orders.advance_to_next_status(order)
    end

    test "rejects advancing a delivered order (no next status)" do
      order = insert(:order, status: :delivered)
      assert {:error, :invalid_transition} = Orders.advance_to_next_status(order)
    end
  end

  describe "get_shopper_order/2" do
    test "returns the shopper's own order with line items and customer preloaded" do
      shopper = insert(:user, role: :shopper)

      order =
        insert(:order,
          shopper: shopper,
          status: :shopping,
          line_items: [build(:line_item, name: "Milk")]
        )

      found = Orders.get_shopper_order(shopper.id, order.id)
      assert found.id == order.id
      assert [%{name: "Milk"}] = found.line_items
      assert found.customer.id == order.customer_id
    end

    test "returns nil for another shopper's order" do
      s1 = insert(:user, role: :shopper)
      s2 = insert(:user, role: :shopper)
      order = insert(:order, shopper: s1, status: :accepted)

      assert Orders.get_shopper_order(s2.id, order.id) == nil
    end
  end

  describe "pool domain events" do
    test "create_order broadcasts :order_created to pool subscribers" do
      :ok = OrderEvents.subscribe_to_pool()
      customer = insert(:user, role: :customer)

      {:ok, order} =
        Orders.create_order(%{
          "customer_id" => customer.id,
          "delivery_address" => "12 Jalan Teluk Sisek, Kuantan",
          "line_items" => [%{"name" => "Milk", "quantity" => "1"}]
        })

      oid = order.id
      assert_receive {:order_created, %Order{id: ^oid}}
    end

    test "claim_order broadcasts :order_claimed to pool subscribers" do
      :ok = OrderEvents.subscribe_to_pool()
      order = insert(:order, status: :pending)
      shopper = insert(:user, role: :shopper)
      oid = order.id

      assert :ok = Orders.claim_order(order.id, shopper.id)
      assert_receive {:order_claimed, ^oid}
    end
  end

  describe "order update events" do
    test "advance_status notifies the order topic" do
      order = insert(:order, status: :accepted)
      :ok = OrderEvents.subscribe_to_order(order.id)

      {:ok, _} = Orders.advance_status(order, :shopping)
      assert_receive {:order_updated, %Order{}}
    end

    test "advance_status notifies the customer topic (their home list)" do
      customer = insert(:user, role: :customer)
      order = insert(:order, customer: customer, status: :accepted)
      :ok = OrderEvents.subscribe_to_customer(customer.id)

      {:ok, _} = Orders.advance_status(order, :shopping)
      assert_receive {:order_updated, %Order{}}
    end

    test "claim_order notifies the order topic" do
      order = insert(:order, status: :pending)
      shopper = insert(:user, role: :shopper)
      :ok = OrderEvents.subscribe_to_order(order.id)

      :ok = Orders.claim_order(order.id, shopper.id)
      assert_receive {:order_updated, %Order{}}
    end

    test "set_item_pickup_status notifies the order topic" do
      order =
        insert(:order,
          status: :shopping,
          line_items: [build(:line_item, pickup_status: :pending)]
        )

      [item] = order.line_items
      :ok = OrderEvents.subscribe_to_order(order.id)

      {:ok, _} = Orders.set_item_pickup_status(item.id, :picked)
      assert_receive {:order_updated, _}
    end
  end
end
