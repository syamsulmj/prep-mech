defmodule PrepMechWeb.Auth do
  @moduledoc """
  Plugs and helpers for cookie-based session authentication.

  There is no token table: a logged-in user is identified solely by a
  `:user_id` stored in the signed Phoenix session. `fetch_current_user/2`
  loads that user into `conn.assigns.current_user` on every request, and the
  `ensure_authenticated/2` / `non_authenticated/2` plugs gate routes based on it.
  """

  use PrepMechWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias PrepMech.Accounts

  @doc """
  Plug that assigns `:current_user` from the session `:user_id` (or `nil`).

  Belongs in the `:browser` pipeline so every request knows who is logged in.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Plug that halts and redirects to `/login` unless a user is logged in.

  Requires `fetch_current_user/2` to have run earlier in the pipeline.
  """
  def ensure_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc """
  Plug that redirects already-authenticated users to `/`.

  Used for guest-only pages such as login and signup, so logged-in users
  don't see them.
  """
  def non_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Plug that halts unless the current user has the given `role`.

  Assumes `fetch_current_user/2` (and usually `ensure_authenticated/2`) ran
  earlier. Used as `plug :require_role, :customer` in a pipeline.
  """
  def require_role(conn, role) do
    if conn.assigns[:current_user] && conn.assigns.current_user.role == role do
      conn
    else
      conn
      |> put_flash(:error, "You don't have access to that page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Logs `user` in by storing their id in a freshly renewed session.
  """
  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
  end

  @doc """
  Logs the current user out by clearing the session.
  """
  def log_out_user(conn) do
    renew_session(conn)
  end

  # Renews the session id and clears its contents to prevent session
  # fixation attacks.
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
