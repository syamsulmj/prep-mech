defmodule PrepMechWeb.PageControllerTest do
  use PrepMechWeb.ConnCase, async: true

  test "GET / redirects to /login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  describe "GET / as a customer" do
    setup %{conn: conn} do
      customer = insert(:user, role: :customer)
      %{conn: log_in_user(conn, customer), customer: customer}
    end

    test "shows the customer's orders", %{conn: conn, customer: customer} do
      insert(:order, customer: customer, line_items: [build(:line_item, name: "Milk")])

      resp = conn |> get(~p"/") |> html_response(200)
      assert resp =~ "Your orders"
      assert resp =~ "Milk"
    end

    test "does not show another customer's orders", %{conn: conn} do
      other = insert(:user, role: :customer)
      insert(:order, customer: other, line_items: [build(:line_item, name: "Secretmilk")])

      refute conn |> get(~p"/") |> html_response(200) =~ "Secretmilk"
    end
  end

  describe "GET / as a shopper" do
    test "shows the dashboard, open pool, and my jobs", %{conn: conn} do
      shopper = insert(:user, role: :shopper)
      insert(:order, status: :pending, line_items: [build(:line_item, name: "Poolmilk")])
      job = insert(:order, status: :shopping, shopper: shopper, line_items: [build(:line_item)])

      resp = conn |> log_in_user(shopper) |> get(~p"/") |> html_response(200)

      assert resp =~ "Available orders"
      assert resp =~ "My jobs"
      # a pending order's items show in the pool
      assert resp =~ "Poolmilk"
      # the shopper's own claimed job shows by its order number
      assert resp =~ "Order ##{job.id}"
      # not the customer view
      refute resp =~ "Your orders"
    end
  end
end
