defmodule PrepMechWeb.UserSocketTest do
  use PrepMechWeb.ChannelCase, async: true

  alias PrepMechWeb.UserSocket

  test "connects with a valid token and binds the user id" do
    token = Phoenix.Token.sign(PrepMechWeb.Endpoint, "user socket", 42)

    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.user_id == 42
  end

  test "rejects a connection with no token" do
    assert :error = connect(UserSocket, %{})
  end

  test "rejects a connection with an invalid token" do
    assert :error = connect(UserSocket, %{"token" => "not-a-real-token"})
  end
end
