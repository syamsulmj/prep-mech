defmodule PrepMechWeb.SessionController do
  use PrepMechWeb, :controller

  alias PrepMech.Accounts
  alias PrepMech.User
  alias PrepMechWeb.Plugs.Auth

  ## Login

  @doc "Renders the login form."
  def login(conn, _params) do
    render(conn, :login, layout: false)
  end

  @doc "Authenticates the submitted credentials and starts a session."
  def validate_login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome back, #{user.name}!")
        |> Auth.log_in_user(user)
        |> redirect(to: ~p"/")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> render(:login, layout: false)
    end
  end

  ## Signup

  @doc "Renders the signup form."
  def signup(conn, _params) do
    render(conn, :signup, changeset: Accounts.change_user_registration(%User{}), layout: false)
  end

  @doc "Creates a user (customer or shopper) and starts a session."
  def create_user(conn, %{"user" => user_params}) do
    register =
      if user_params["role"] == "shopper",
        do: &Accounts.register_shopper/1,
        else: &Accounts.register_customer/1

    case register.(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Account created. Welcome, #{user.name}!")
        |> Auth.log_in_user(user)
        |> redirect(to: ~p"/")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :signup, changeset: changeset, layout: false)
    end
  end

  ## Logout

  @doc "Clears the session and returns to the login page."
  def logout(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out.")
    |> Auth.log_out_user()
    |> redirect(to: ~p"/login")
  end
end
