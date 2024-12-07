defmodule TrySyndicateWeb.EditorLive do
  use TrySyndicateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :output, "")}
  end

  def handle_event("run_code", %{"code" => code}, socket) do
    # Process the code here
    result = run_code(code)

    {:noreply, assign(socket, :output, result)}
  end

  defp run_code(code) do
    "Submitted code: #{code}"
  end
end
