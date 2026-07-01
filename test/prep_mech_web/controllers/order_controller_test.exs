defmodule PrepMechWeb.OrderControllerTest do
  use PrepMechWeb.ConnCase, async: true

  alias PrepMech.Orders

  setup %{conn: conn} do
    customer = insert(:user, role: :customer)
    %{conn: log_in_user(conn, customer), customer: customer}
  end

  describe "GET /orders/new" do
    test "renders the new order form", %{conn: conn} do
      assert conn |> get(~p"/orders/new") |> html_response(200) =~ "New order"
    end

    test "blocks shoppers from the customer routes", %{conn: _conn} do
      conn = log_in_user(build_conn(), insert(:user, role: :shopper))
      conn = get(conn, ~p"/orders/new")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /orders" do
    test "creates an order for the current customer and redirects to it", %{
      conn: conn,
      customer: customer
    } do
      params = %{
        "delivery_address" => "9 Test Road",
        "notes" => "Ring the bell",
        "line_items" => [%{"name" => "Milk", "quantity" => "2"}]
      }

      conn = post(conn, ~p"/orders", %{"order" => params})

      assert redirected_to(conn) =~ ~r"/orders/\d+"
      assert [order] = Orders.list_for_customer(customer.id)
      assert order.customer_id == customer.id
      assert [%{name: "Milk", quantity: 2}] = order.line_items
    end

    test "creates every line item from indexed, form-encoded params", %{
      conn: conn,
      customer: customer
    } do
      # Exercises the real Plug param parsing (a raw urlencoded body), which the
      # map-based test above bypasses. Guards against the `[][name]` collapse bug.
      body =
        "order[delivery_address]=9+Test+Road" <>
          "&order[line_items][0][name]=Milk&order[line_items][0][quantity]=2" <>
          "&order[line_items][1][name]=Bread&order[line_items][1][quantity]=1"

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/orders", body)

      assert redirected_to(conn) =~ ~r"/orders/\d+"
      assert [order] = Orders.list_for_customer(customer.id)
      assert length(order.line_items) == 2
      assert Enum.map(order.line_items, & &1.name) |> Enum.sort() == ["Bread", "Milk"]
    end

    test "re-renders the form when the order is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/orders", %{"order" => %{"delivery_address" => "", "line_items" => []}})

      assert html_response(conn, 200) =~ "New order"
    end
  end

  describe "GET /orders/:id" do
    test "shows the customer's own order", %{conn: conn, customer: customer} do
      order =
        insert(:order,
          customer: customer,
          status: :shopping,
          line_items: [build(:line_item, name: "Milk", pickup_status: :picked)]
        )

      resp = conn |> get(~p"/orders/#{order}") |> html_response(200)
      assert resp =~ "Milk"
      assert resp =~ "Shopping"
    end

    test "redirects when the order belongs to another customer", %{conn: conn} do
      other = insert(:user, role: :customer)
      order = insert(:order, customer: other)

      conn = get(conn, ~p"/orders/#{order}")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
