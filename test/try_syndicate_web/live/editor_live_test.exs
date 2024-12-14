defmodule TrySyndicateWeb.EditorLiveTest do
  use TrySyndicateWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mox

  alias TrySyndicate.MockSessionManager

  test "renders the editor live view", %{conn: conn} do
    expect(MockSessionManager, :start_session, fn -> {:ok, "1234"} end)
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Welcome to Syndicate"
  end

  test "displays error flash message when session fails to start", %{conn: conn} do
    expect(MockSessionManager, :start_session, fn -> {:error, "Failed to start session"} end)

    {:ok, view, _html} = live(conn, "/")
    assert render(view) =~ "Failed to start session"
  end

  test "disables run button when session fails to start", %{conn: conn} do
    expect(MockSessionManager, :start_session, fn -> {:error, "Failed to start session"} end)

    {:ok, view, _html} = live(conn, "/")
    refute has_element?(view, "form > button")
  end

  test "enables run button when session starts successfully", %{conn: conn} do
    expect(MockSessionManager, :start_session, fn -> {:ok, "1234"} end)
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "form > button")
  end

end
