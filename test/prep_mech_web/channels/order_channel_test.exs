defmodule PrepMechWeb.OrderChannelTest do
  # Not async: join/3 queries the DB, so the channel process needs the shared sandbox.
  use PrepMechWeb.ChannelCase

  alias PrepMech.Order
  alias PrepMechWeb.OrderChannel
  alias PrepMechWeb.UserSocket

  defp connect_as(user) do
    token = Phoenix.Token.sign(PrepMechWeb.Endpoint, "user socket", user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    socket
  end

  describe "order:<id>" do
    test "the owning customer can join and receives updates" do
      customer = insert(:user, role: :customer)
      order = insert(:order, customer: customer, line_items: [build(:line_item)])

      assert {:ok, _reply, _socket} =
               customer |> connect_as() |> subscribe_and_join(OrderChannel, "order:#{order.id}")

      Phoenix.PubSub.broadcast(PrepMech.PubSub, "order:#{order.id}", {:order_updated, %Order{}})
      assert_push "updated", %{}
    end

    test "a different customer is refused" do
      order = insert(:order, customer: insert(:user, role: :customer))
      other = insert(:user, role: :customer)

      assert {:error, %{reason: "unauthorized"}} =
               other |> connect_as() |> subscribe_and_join(OrderChannel, "order:#{order.id}")
    end
  end

  describe "customer:<id>" do
    test "a customer can join their own topic" do
      customer = insert(:user, role: :customer)

      assert {:ok, _reply, _socket} =
               customer
               |> connect_as()
               |> subscribe_and_join(OrderChannel, "customer:#{customer.id}")
    end

    test "a customer cannot join another customer's topic" do
      c1 = insert(:user, role: :customer)
      c2 = insert(:user, role: :customer)

      assert {:error, %{reason: "unauthorized"}} =
               c1 |> connect_as() |> subscribe_and_join(OrderChannel, "customer:#{c2.id}")
    end
  end
end
