defmodule PrepMechWeb.PWATest do
  use PrepMechWeb.ConnCase, async: true

  describe "manifest + offline page" do
    test "GET /manifest.json serves a valid web app manifest", %{conn: conn} do
      conn = get(conn, "/manifest.json")

      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "json"

      manifest = Jason.decode!(conn.resp_body)
      assert manifest["name"] == "PrepMech"
      assert manifest["start_url"] == "/"
      assert manifest["display"] == "standalone"
      assert manifest["background_color"] == "#0c0d10"
      assert is_list(manifest["icons"]) and length(manifest["icons"]) >= 1
    end

    test "GET /offline.html serves the offline fallback page", %{conn: conn} do
      conn = get(conn, "/offline.html")

      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "text/html"
      assert conn.resp_body =~ "You're offline"
    end
  end

  describe "app icons" do
    test "GET /images/icon-192.png serves the 192px app icon", %{conn: conn} do
      conn = get(conn, "/images/icon-192.png")
      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "image/png"
    end

    test "GET /images/icon-512.png serves the 512px app icon", %{conn: conn} do
      conn = get(conn, "/images/icon-512.png")
      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "image/png"
    end
  end

  describe "service worker" do
    test "GET /sw.js serves the service worker at the root scope", %{conn: conn} do
      conn = get(conn, "/sw.js")

      assert conn.status == 200
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "javascript"

      # sanity: it is our SW, not some other file (version-agnostic so a cache bump won't break this)
      assert conn.resp_body =~ "prepmech-static-"
    end
  end

  describe "layout wiring" do
    setup %{conn: conn} do
      %{conn: log_in_user(conn, insert(:user, role: :customer))}
    end

    test "root layout links the manifest and sets theme-color", %{conn: conn} do
      resp = conn |> get(~p"/") |> html_response(200)

      assert resp =~ ~s(rel="manifest")
      assert resp =~ ~s(href="/manifest.json")
      assert resp =~ ~s(name="theme-color")
      assert resp =~ ~s(content="#0c0d10")
    end

    test "interior layout renders the offline banner", %{conn: conn} do
      resp = conn |> get(~p"/") |> html_response(200)

      assert resp =~ ~s(id="offline-banner")
      assert resp =~ "Offline · showing last-known state"
    end
  end
end
