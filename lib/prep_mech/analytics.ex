defmodule PrepMech.Analytics do
  @moduledoc """
  Read-only reporting and aggregation over orders.

  This context answers "what do all orders look like in aggregate?" — the
  query side that powers the shopper dashboard. The order lifecycle itself
  (create, claim, advance, resolve items) lives in `PrepMech.Orders`.
  """

  import Ecto.Query

  alias PrepMech.Order
  alias PrepMech.Repo

  @doc """
  Counts orders grouped by status, with every status present (zeros included).

  Powers the shopper dashboard tiles.
  """
  def dashboard_summary() do
    counts =
      Order
      |> group_by([o], o.status)
      |> select([o], {o.status, count(o.id)})
      |> Repo.all()
      |> Map.new()

    Map.merge(zero_summary(), counts)
  end

  defp zero_summary() do
    Map.new(Order.statuses(), fn status -> {status, 0} end)
  end
end
