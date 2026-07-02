defmodule PrepMechWeb.PageController do
  use PrepMechWeb, :controller

  alias PrepMech.Analytics
  alias PrepMech.Orders

  @doc """
  The authenticated home, dispatched by role.

  Customers land on their orders list; shoppers get their workspace: the
  dashboard summary, the open pool, and their own active jobs.
  """
  def home(conn, _params) do
    render_home(conn, conn.assigns.current_user)
  end

  defp render_home(conn, %{role: :customer} = user) do
    render(conn, :home, orders: Orders.list_for_customer(user.id))
  end

  defp render_home(conn, %{role: :shopper} = user) do
    render(conn, :shopper_home,
      summary: Analytics.dashboard_summary(),
      pool: Orders.list_pool(),
      jobs: Orders.list_for_shopper(user.id)
    )
  end
end
