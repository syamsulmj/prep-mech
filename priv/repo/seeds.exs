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

Repo.delete_all(
  from u in User,
    where: u.email in ["customer@demo.com", "shopper1@demo.com", "shopper2@demo.com"]
)

# --- accounts --------------------------------------------------------------
{:ok, customer} =
  Accounts.register_customer(%{
    name: "Sam Rivera",
    email: "customer@demo.com",
    phone: "+60123456789",
    address: "12 Jalan Teluk Sisek, 25000 Kuantan, Pahang",
    password: "password123"
  })

{:ok, shopper1} =
  Accounts.register_shopper(%{
    name: "Aisha Rahman",
    email: "shopper1@demo.com",
    phone: "+60129876543",
    address: "Indera Mahkota, 25200 Kuantan, Pahang",
    password: "password123"
  })

{:ok, shopper2} =
  Accounts.register_shopper(%{
    name: "Meon Peon",
    email: "shopper2@demo.com",
    phone: "+60129876543",
    address: "Tanjung Lumpur, 26060 Kuantan, Pahang",
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

claim = fn order, shopper ->
  :ok = Orders.claim_order(order.id, shopper.id)
  order
end

claim_and_shop = fn order, shopper ->
  claim.(order, shopper)
  {:ok, _} = Orders.advance_status(Orders.get_order!(order.id), :shopping)
  order
end

# --- orders across the lifecycle, split between both shoppers -------------

# 1) pending — two orders waiting in the pool (unclaimed)
create.([{"Milk", "2"}, {"Bread", "1"}, {"Eggs", "12"}], "Ring the bell twice")
create.([{"Sugar", "1"}, {"Flour", "2"}, {"Butter", "2"}], nil)

# 2) accepted — Meon just claimed it, hasn't started shopping yet
accepted = create.([{"Apples", "6"}, {"Oranges", "4"}], nil)
claim.(accepted, shopper2)

# 3) shopping — Aisha mid-run: some picked, one unavailable, some still pending
shopping =
  create.([{"Milk", "2"}, {"Bread", "1"}, {"Eggs", "12"}, {"Butter", "1"}, {"Rice", "1"}], nil)

claim_and_shop.(shopping, shopper1)
[a, b, c | _] = shopping.line_items
Orders.set_item_pickup_status(a.id, :picked)
Orders.set_item_pickup_status(b.id, :picked)
Orders.set_item_pickup_status(c.id, :unavailable)

# 4) out for delivery — Meon, all items resolved
delivery =
  create.([{"Coffee", "1"}, {"Oat milk", "2"}, {"Bananas", "6"}], "Leave at the guardhouse")

claim_and_shop.(delivery, shopper2)
Enum.each(delivery.line_items, &Orders.set_item_pickup_status(&1.id, :picked))
{:ok, _} = Orders.advance_status(Orders.get_order!(delivery.id), :on_delivery)

# 5) delivered — Aisha, completed run, one item was unavailable
delivered =
  create.([{"Rice", "1"}, {"Chicken", "1"}, {"Chili paste", "2"}, {"Soy sauce", "1"}], nil)

claim_and_shop.(delivered, shopper1)
[d1, d2, d3, d4] = delivered.line_items
Enum.each([d1, d2, d3], &Orders.set_item_pickup_status(&1.id, :picked))
Orders.set_item_pickup_status(d4.id, :unavailable)
{:ok, delivered} = Orders.advance_status(Orders.get_order!(delivered.id), :on_delivery)
{:ok, _} = Orders.advance_status(delivered, :delivered)

IO.puts("""
Seeded demo data:
  customer@demo.com   / password123  (Sam Rivera)
  shopper1@demo.com   / password123  (Aisha Rahman)  — shopping + delivered
  shopper2@demo.com   / password123  (Meon Peon)     — accepted + out-for-delivery
  6 orders: 2 pending (pool), accepted, shopping, out-for-delivery, delivered
""")
