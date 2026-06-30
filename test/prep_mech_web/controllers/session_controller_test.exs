defmodule PrepMechWeb.SessionControllerTest do
  use PrepMechWeb.ConnCase, async: true

  alias PrepMech.Accounts

  describe "GET /login" do
    test "renders the login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~s(name="user[email]")
    end

    test "redirects authenticated users to /", %{conn: conn} do
      conn = conn |> log_in_user(insert(:user)) |> get(~p"/login")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /login" do
    test "logs the user in with valid credentials", %{conn: conn} do
      user = insert(:user)

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => valid_password()}
        })

      assert get_session(conn, :user_id) == user.id
      assert redirected_to(conn) == ~p"/"
    end

    test "re-renders the form with an error on invalid credentials", %{conn: conn} do
      user = insert(:user)

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => "wrong password"}
        })

      assert html_response(conn, 200) =~ "Log in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
      refute get_session(conn, :user_id)
    end
  end

  describe "GET /signup" do
    test "renders the signup form with user-namespaced fields", %{conn: conn} do
      conn = get(conn, ~p"/signup")
      response = html_response(conn, 200)
      assert response =~ "Create an account"
      assert response =~ ~s(name="user[email]")
    end
  end

  describe "POST /signup" do
    test "creates a customer and logs them in", %{conn: conn} do
      params = %{
        "name" => "Sam",
        "email" => "sam@example.com",
        "phone" => "0123456777",
        "address" => "No 18",
        "password" => "user1234",
        "role" => "customer"
      }

      conn = post(conn, ~p"/signup", %{"user" => params})

      assert redirected_to(conn) == ~p"/"
      user = Accounts.get_user_by_email("sam@example.com")
      assert user.role == :customer
      assert get_session(conn, :user_id) == user.id
    end

    test "creates a shopper when role is shopper", %{conn: conn} do
      params = %{
        "name" => "Pat",
        "email" => "pat@example.com",
        "password" => "user1234",
        "role" => "shopper"
      }

      conn = post(conn, ~p"/signup", %{"user" => params})

      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_user_by_email("pat@example.com").role == :shopper
    end

    test "re-renders with errors on invalid data", %{conn: conn} do
      conn = post(conn, ~p"/signup", %{"user" => %{"email" => "nope"}})

      response = html_response(conn, 200)
      assert response =~ "Create an account"
      assert response =~ "must have the @ sign and no spaces"
      refute get_session(conn, :user_id)
    end
  end

  describe "DELETE /logout" do
    test "clears the session and redirects to /login", %{conn: conn} do
      conn = conn |> log_in_user(insert(:user)) |> delete(~p"/logout")
      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, :user_id)
    end
  end
end
