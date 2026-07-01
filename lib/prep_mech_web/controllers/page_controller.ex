defmodule PrepMechWeb.PageController do
  use PrepMechWeb, :controller

  alias PrepMech.Orders

  @doc """
  The authenticated home, dispatched by role.

  Customers land on their orders list; shoppers get their workspace (a
  placeholder until Phase 3 builds the pool + dashboard).
  """
  def home(conn, _params) do
    render_home(conn, conn.assigns.current_user)
  end

  defp render_home(conn, %{role: :customer} = user) do
    render(conn, :home, orders: Orders.list_for_customer(user.id))
  end

  defp render_home(conn, %{role: :shopper}) do
    render(conn, :shopper_home)
  end
end
