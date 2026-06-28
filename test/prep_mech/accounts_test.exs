defmodule PrepMech.AccountsTest do
  use PrepMech.DataCase, async: true

  alias PrepMech.Accounts
  alias PrepMech.User

  describe "list_users/0" do
    test "returns all users" do
      u1 = insert(:user)
      u2 = insert(:user)

      ids = Accounts.list_users() |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == Enum.sort([u1.id, u2.id])
    end

    test "returns an empty list when there are no users" do
      assert Accounts.list_users() == []
    end
  end

  describe "get_user!/1" do
    test "returns the user with the given id" do
      user = insert(:user)
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "raises when the user does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(-1) end
    end
  end

  describe "get_user/1" do
    test "returns the user with the given id" do
      user = insert(:user)
      assert Accounts.get_user(user.id).id == user.id
    end

    test "returns nil when the user does not exist" do
      refute Accounts.get_user(-1)
    end
  end

  describe "get_user_by_email/1" do
    test "returns the user with the given email" do
      user = insert(:user)
      assert Accounts.get_user_by_email(user.email).id == user.id
    end

    test "returns nil when the email is not found" do
      refute Accounts.get_user_by_email("nobody@example.com")
    end
  end

  describe "register_customer/1" do
    test "creates a customer with a hashed password" do
      attrs = valid_registration_attrs()

      assert {:ok, %User{} = user} = Accounts.register_customer(attrs)
      assert user.email == attrs.email
      assert user.name == attrs.name
      assert user.role == :customer
      assert is_binary(user.password_hashed)
      # virtual password is cleared after hashing, never persisted in plaintext
      assert is_nil(user.password)
      assert User.valid_password?(user, valid_password())
    end

    test "returns an error changeset when required fields are missing" do
      assert {:error, changeset} = Accounts.register_customer(%{})
      errors = errors_on(changeset)
      assert errors.name == ["can't be blank"]
      assert errors.email == ["can't be blank"]
      assert errors.password == ["can't be blank"]
    end

    test "rejects a password shorter than 6 characters" do
      attrs = valid_registration_attrs(password: "123")
      assert {:error, changeset} = Accounts.register_customer(attrs)
      assert "should be at least 6 character(s)" in errors_on(changeset).password
    end

    test "rejects a malformed email" do
      attrs = valid_registration_attrs(email: "not an email")
      assert {:error, changeset} = Accounts.register_customer(attrs)
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "rejects a duplicate email" do
      existing = insert(:user)
      attrs = valid_registration_attrs(email: existing.email)

      assert {:error, changeset} = Accounts.register_customer(attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "does not let the role be overridden via params" do
      attrs = valid_registration_attrs(role: :shopper)
      assert {:ok, %User{role: :customer}} = Accounts.register_customer(attrs)
    end
  end

  describe "register_shopper/1" do
    test "creates a user with the shopper role" do
      assert {:ok, %User{role: :shopper}} =
               Accounts.register_shopper(valid_registration_attrs())
    end
  end

  describe "change_user_registration/3" do
    test "returns a changeset for a new user" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      refute changeset.valid?
    end

    test "returns a valid changeset when given valid attrs" do
      changeset = Accounts.change_user_registration(%User{}, valid_registration_attrs())
      assert changeset.valid?
    end
  end

  describe "authenticate_user/2" do
    test "returns {:ok, user} with valid credentials" do
      user = insert(:user)
      assert {:ok, authed} = Accounts.authenticate_user(user.email, valid_password())
      assert authed.id == user.id
    end

    test "returns {:error, :unauthorized} with a wrong password" do
      user = insert(:user)
      assert {:error, :unauthorized} = Accounts.authenticate_user(user.email, "wrong password")
    end

    test "returns {:error, :unauthorized} when the email is unknown" do
      assert {:error, :unauthorized} =
               Accounts.authenticate_user("nobody@example.com", valid_password())
    end
  end
end
