defmodule PrepMechWeb.PageHTMLTest do
  use ExUnit.Case, async: true

  alias PrepMechWeb.PageHTML

  defp ago(seconds), do: NaiveDateTime.add(NaiveDateTime.utc_now(), -seconds, :second)

  describe "time_ago/1" do
    test "just now for very recent times" do
      assert PageHTML.time_ago(ago(5)) == "just now"
    end

    test "minutes, hours, and days" do
      assert PageHTML.time_ago(ago(5 * 60)) == "5 min ago"
      assert PageHTML.time_ago(ago(2 * 3600)) == "2 hr ago"
      assert PageHTML.time_ago(ago(1 * 86_400)) == "1 day ago"
      assert PageHTML.time_ago(ago(3 * 86_400)) == "3 days ago"
    end
  end

  describe "recent?/2" do
    test "true within the window, false outside" do
      assert PageHTML.recent?(ago(3 * 60), 10)
      refute PageHTML.recent?(ago(20 * 60), 10)
    end

    test "defaults to a 10 minute window" do
      assert PageHTML.recent?(ago(60))
      refute PageHTML.recent?(ago(11 * 60))
    end
  end
end
