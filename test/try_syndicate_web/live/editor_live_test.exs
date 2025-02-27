defmodule TrySyndicateWeb.EditorLiveTest do
  use TrySyndicateWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mox

  alias TrySyndicate.MockSessionManager

  describe "Basic functionality" do
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

  describe "Starting a new session" do
    test "starts a new session and resets state", %{conn: conn} do
      session_id = "test_session_123"

      expect(MockSessionManager, :start_session, fn ->
        {:ok, session_id}
      end)

      {:ok, view, _html} = live(conn, "/")

      TrySyndicateWeb.Endpoint.broadcast("session:#{session_id}", "terminate", %{
        reason: "test reason"
      })

      assert render(view) =~ "Session Finished"

      expect(MockSessionManager, :start_session, fn ->
        {:ok, "new_session_456"}
      end)

      new_session_button = element(view, "button", "Start New Session")

      html = render_click(new_session_button)

      assert !(html =~ "Session Finished")
    end
  end
end
