defmodule PrepMechWeb.JobControllerTest do
  use PrepMechWeb.ConnCase, async: true

  alias PrepMech.LineItem
  alias PrepMech.Orders
  alias PrepMech.Repo

  setup %{conn: conn} do
    shopper = insert(:user, role: :shopper)
    %{conn: log_in_user(conn, shopper), shopper: shopper}
  end

  describe "POST /jobs/:id/claim" do
    test "claims a pending order and redirects to the job", %{conn: conn, shopper: shopper} do
      order = insert(:order, status: :pending)

      conn = post(conn, ~p"/jobs/#{order}/claim")

      assert redirected_to(conn) == ~p"/jobs/#{order}"
      claimed = Orders.get_order!(order.id)
      assert claimed.status == :accepted
      assert claimed.shopper_id == shopper.id
    end

    test "redirects home when the order was already claimed", %{conn: conn} do
      order = insert(:order, status: :accepted, shopper: insert(:user, role: :shopper))

      conn = post(conn, ~p"/jobs/#{order}/claim")
      assert redirected_to(conn) == ~p"/"
    end

    test "blocks customers from shopper routes", %{conn: _conn} do
      conn = log_in_user(build_conn(), insert(:user, role: :customer))
      order = insert(:order, status: :pending)

      conn = post(conn, ~p"/jobs/#{order}/claim")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "GET /jobs/:id" do
    test "shows the shopper's own job", %{conn: conn, shopper: shopper} do
      order =
        insert(:order,
          shopper: shopper,
          status: :shopping,
          line_items: [build(:line_item, name: "Milk")]
        )

      assert conn |> get(~p"/jobs/#{order}") |> html_response(200) =~ "Milk"
    end

    test "redirects when the job belongs to another shopper", %{conn: conn} do
      order = insert(:order, shopper: insert(:user, role: :shopper), status: :accepted)

      conn = get(conn, ~p"/jobs/#{order}")
      assert redirected_to(conn) == ~p"/"
    end

    test "renders offline-queue hooks on the item toggles", %{conn: conn, shopper: shopper} do
      order =
        insert(:order,
          shopper: shopper,
          status: :shopping,
          line_items: [build(:line_item, name: "Milk", pickup_status: :pending)]
        )

      html = conn |> get(~p"/jobs/#{order}") |> html_response(200)

      assert html =~ ~s(data-toggle="picked")
      assert html =~ ~s(data-toggle="unavailable")
      assert html =~ "data-class-active"
      assert html =~ "data-class-inactive"
      assert html =~ "data-item-id"
      assert html =~ "data-queued-badge"
    end

    test "renders the location-sender when the job is on delivery", %{
      conn: conn,
      shopper: shopper
    } do
      order =
        insert(:order, shopper: shopper, status: :on_delivery, line_items: [build(:line_item)])

      resp = conn |> get(~p"/jobs/#{order}") |> html_response(200)

      assert resp =~ ~s(id="location-sender")
      assert resp =~ ~s(data-order-id="#{order.id}")
    end
  end

  describe "POST /jobs/:id/advance" do
    test "advances the job to the next status", %{conn: conn, shopper: shopper} do
      order = insert(:order, shopper: shopper, status: :accepted)

      conn = post(conn, ~p"/jobs/#{order}/advance")

      assert redirected_to(conn) == ~p"/jobs/#{order}"
      assert Orders.get_order!(order.id).status == :shopping
    end

    test "is blocked by the resolved-items gate", %{conn: conn, shopper: shopper} do
      order =
        insert(:order,
          shopper: shopper,
          status: :shopping,
          line_items: [build(:line_item, pickup_status: :pending)]
        )

      post(conn, ~p"/jobs/#{order}/advance")
      assert Orders.get_order!(order.id).status == :shopping
    end
  end

  describe "POST /jobs/:id/items/:item_id" do
    setup %{shopper: shopper} do
      order =
        insert(:order,
          shopper: shopper,
          status: :shopping,
          line_items: [build(:line_item, pickup_status: :pending)]
        )

      [order: order, item: hd(order.line_items)]
    end

    test "marks an item picked", %{conn: conn, order: order, item: item} do
      conn = post(conn, ~p"/jobs/#{order}/items/#{item.id}", %{"status" => "picked"})

      assert redirected_to(conn) == ~p"/jobs/#{order}"
      assert Repo.get(LineItem, item.id).pickup_status == :picked
    end

    test "marks an item unavailable", %{conn: conn, order: order, item: item} do
      post(conn, ~p"/jobs/#{order}/items/#{item.id}", %{"status" => "unavailable"})
      assert Repo.get(LineItem, item.id).pickup_status == :unavailable
    end
  end
end
