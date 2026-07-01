# Demo data for PrepMech. Run with:
#
#     mix run priv/repo/seeds.exs
#
# Idempotent: it clears existing orders + the demo accounts first, then rebuilds
# a customer, a shopper, and a set of orders spread across the lifecycle by
# driving the real Orders context (claim -> shop -> deliver).

import Ecto.Query

alias PrepMech.Accounts
alias PrepMech.LineItem
alias PrepMech.Order
alias PrepMech.Orders
alias PrepMech.Repo
alias PrepMech.User

# --- reset demo data -------------------------------------------------------
Repo.delete_all(LineItem)
Repo.delete_all(Order)
Repo.delete_all(from u in User, where: u.email in ["customer@demo.com", "shopper@demo.com"])

# --- accounts --------------------------------------------------------------
{:ok, customer} =
  Accounts.register_customer(%{
    name: "Sam Rivera",
    email: "customer@demo.com",
    phone: "+60123456789",
    address: "12 Jalan Teluk Sisek, 25000 Kuantan, Pahang",
    password: "password123"
  })

{:ok, shopper} =
  Accounts.register_shopper(%{
    name: "Aisha Rahman",
    email: "shopper@demo.com",
    phone: "+60129876543",
    address: "Indera Mahkota, 25200 Kuantan, Pahang",
    password: "password123"
  })

# --- helpers ---------------------------------------------------------------
create = fn items, notes ->
  {:ok, order} =
    Orders.create_order(%{
      "customer_id" => customer.id,
      "delivery_address" => customer.address,
      "notes" => notes,
      "line_items" => Enum.map(items, fn {name, qty} -> %{"name" => name, "quantity" => qty} end)
    })

  order
end

claim_and_shop = fn order ->
  :ok = Orders.claim_order(order.id, shopper.id)
  {:ok, _} = Orders.advance_status(Orders.get_order!(order.id), :shopping)
  order
end

# --- orders across the lifecycle ------------------------------------------

# 1) pending — waiting in the pool
create.([{"Milk", "2"}, {"Bread", "1"}, {"Eggs", "12"}], "Ring the bell twice")

# 2) shopping — some items resolved, one unavailable, some pending
shopping =
  create.([{"Milk", "2"}, {"Bread", "1"}, {"Eggs", "12"}, {"Butter", "1"}, {"Rice", "1"}], nil)

claim_and_shop.(shopping)
[a, b, c | _] = shopping.line_items
Orders.set_item_pickup_status(a.id, :picked)
Orders.set_item_pickup_status(b.id, :picked)
Orders.set_item_pickup_status(c.id, :unavailable)

# 3) out for delivery — all items resolved
delivery =
  create.([{"Coffee", "1"}, {"Oat milk", "2"}, {"Bananas", "6"}], "Leave at the guardhouse")

claim_and_shop.(delivery)
Enum.each(delivery.line_items, &Orders.set_item_pickup_status(&1.id, :picked))
{:ok, _} = Orders.advance_status(Orders.get_order!(delivery.id), :on_delivery)

# 4) delivered — completed run, one item was unavailable
delivered =
  create.([{"Rice", "1"}, {"Chicken", "1"}, {"Chili paste", "2"}, {"Soy sauce", "1"}], nil)

claim_and_shop.(delivered)
[d1, d2, d3, d4] = delivered.line_items
Enum.each([d1, d2, d3], &Orders.set_item_pickup_status(&1.id, :picked))
Orders.set_item_pickup_status(d4.id, :unavailable)
{:ok, delivered} = Orders.advance_status(Orders.get_order!(delivered.id), :on_delivery)
{:ok, _} = Orders.advance_status(delivered, :delivered)

IO.puts("""
Seeded demo data:
  customer@demo.com / password123  (Sam Rivera)
  shopper@demo.com  / password123  (Aisha Rahman)
  4 orders: pending, shopping, out-for-delivery, delivered
""")
