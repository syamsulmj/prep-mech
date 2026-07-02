defmodule PrepMechWeb.JobController do
  use PrepMechWeb, :controller

  alias PrepMech.Order
  alias PrepMech.Orders

  @doc "Atomically claims a pending order for the current shopper."
  def claim(conn, %{"id" => id}) do
    case Orders.claim_order(id, conn.assigns.current_user.id) do
      :ok ->
        conn
        |> put_flash(:info, "Order claimed — happy shopping!")
        |> redirect(to: ~p"/jobs/#{id}")

      {:error, :already_claimed} ->
        conn
        |> put_flash(:error, "Someone grabbed that one first.")
        |> redirect(to: ~p"/")
    end
  end

  @doc "The working view for a job the current shopper owns."
  def show(conn, %{"id" => id}) do
    case Orders.get_shopper_order(conn.assigns.current_user.id, id) do
      nil ->
        conn |> put_flash(:error, "Job not found.") |> redirect(to: ~p"/")

      order ->
        render(conn, :show, order: order)
    end
  end

  @doc "Advances the job to the next lifecycle status (gated server-side)."
  def advance(conn, %{"id" => id}) do
    with %Order{} = order <- Orders.get_shopper_order(conn.assigns.current_user.id, id),
         {:ok, _} <- Orders.advance_to_next_status(order) do
      conn |> put_flash(:info, "Status updated.") |> redirect(to: ~p"/jobs/#{id}")
    else
      nil ->
        conn |> put_flash(:error, "Job not found.") |> redirect(to: ~p"/")

      {:error, :unresolved_items} ->
        conn
        |> put_flash(:error, "Resolve every item before heading out for delivery.")
        |> redirect(to: ~p"/jobs/#{id}")

      {:error, :invalid_transition} ->
        conn
        |> put_flash(:error, "This order can't be advanced.")
        |> redirect(to: ~p"/jobs/#{id}")
    end
  end

  @doc "Marks a line item picked or unavailable while shopping."
  def set_item(conn, %{"id" => id, "item_id" => item_id, "status" => status}) do
    order = Orders.get_shopper_order(conn.assigns.current_user.id, id)

    cond do
      is_nil(order) ->
        conn |> put_flash(:error, "Job not found.") |> redirect(to: ~p"/")

      is_nil(item_status(status)) ->
        redirect(conn, to: ~p"/jobs/#{id}")

      true ->
        Orders.set_item_pickup_status(item_id, item_status(status))
        redirect(conn, to: ~p"/jobs/#{id}")
    end
  end

  # Explicit mapping — never build atoms from untrusted params.
  defp item_status("picked"), do: :picked
  defp item_status("unavailable"), do: :unavailable
  defp item_status(_), do: nil
end
