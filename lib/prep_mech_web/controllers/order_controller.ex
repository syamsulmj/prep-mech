defmodule PrepMechWeb.OrderController do
  use PrepMechWeb, :controller

  alias PrepMech.Orders

  @doc "Renders the new-order form, delivery address prefilled from the account."
  def new(conn, _params) do
    changeset = Orders.change_order(%{"delivery_address" => conn.assigns.current_user.address})
    render(conn, :new, changeset: changeset)
  end

  @doc "Creates an order owned by the current customer."
  def create(conn, %{"order" => order_params}) do
    attrs = Map.put(order_params, "customer_id", conn.assigns.current_user.id)

    case Orders.create_order(attrs) do
      {:ok, order} ->
        conn
        |> put_flash(:info, "Order placed.")
        |> redirect(to: ~p"/orders/#{order}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Please fix the errors below.")
        |> render(:new, changeset: changeset)
    end
  end

  @doc "Shows a single order the current customer owns, or redirects away."
  def show(conn, %{"id" => id}) do
    case Orders.get_customer_order(conn.assigns.current_user.id, id) do
      nil ->
        conn
        |> put_flash(:error, "Order not found.")
        |> redirect(to: ~p"/")

      order ->
        render(conn, :show, order: order)
    end
  end
end
