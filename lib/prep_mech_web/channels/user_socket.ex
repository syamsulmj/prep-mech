defmodule PrepMechWeb.UserSocket do
  use Phoenix.Socket

  channel "orders:pool", PrepMechWeb.PoolChannel
  channel "order:*", PrepMechWeb.OrderChannel
  channel "customer:*", PrepMechWeb.OrderChannel

  # Signed-token auth: only clients holding a valid token (issued to a
  # logged-in user and rendered into the page) may connect, and the connection
  # is bound to that user id — so a middleman can neither connect nor forge who
  # they are. Channel joins authorize against this id.
  @max_age 86_400

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(PrepMechWeb.Endpoint, "user socket", token, max_age: @max_age) do
      {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
      {:error, _reason} -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
