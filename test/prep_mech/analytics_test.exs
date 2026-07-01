defmodule PrepMech.AnalyticsTest do
  use PrepMech.DataCase, async: true

  alias PrepMech.Analytics

  describe "dashboard_summary/0" do
    test "counts orders grouped by status, with zeros for empty statuses" do
      insert(:order, status: :pending)
      insert(:order, status: :pending)
      insert(:order, status: :delivered)

      summary = Analytics.dashboard_summary()

      assert summary.pending == 2
      assert summary.delivered == 1
      assert summary.shopping == 0
      assert summary.accepted == 0
      assert summary.on_delivery == 0
    end
  end
end
