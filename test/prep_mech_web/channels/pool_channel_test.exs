defmodule PrepMechWeb.PoolChannelTest do
  use PrepMechWeb.ChannelCase, async: true

  setup do
    {:ok, _, socket} =
      PrepMechWeb.UserSocket
      |> socket("pool_socket", %{})
      |> subscribe_and_join(PrepMechWeb.PoolChannel, "orders:pool")

    %{socket: socket}
  end

  test "pushes order_created with a summary and delivery address when one is broadcast", %{
    socket: _socket
  } do
    order =
      insert(:order,
        status: :pending,
        delivery_address: "5 Channel Road, Kuantan",
        line_items: [build(:line_item, name: "Channelmilk")]
      )

    Phoenix.PubSub.broadcast(PrepMech.PubSub, "orders:pool", {:order_created, order})

    assert_push "order_created", %{
      summary: "Channelmilk",
      delivery_address: "5 Channel Road, Kuantan"
    }
  end

  test "pushes order_claimed with the order id when a claim is broadcast", %{socket: _socket} do
    Phoenix.PubSub.broadcast(PrepMech.PubSub, "orders:pool", {:order_claimed, 987_654})

    assert_push "order_claimed", %{id: 987_654}
  end
end
