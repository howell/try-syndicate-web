defmodule TrySyndicateWeb.CodeMirrorComponent do
  use TrySyndicateWeb, :live_component

  def render(assigns) do
    ~H"""
    <span class="w-auto h-auto">
      <div id="editor" phx-hook="CodeMirror" class="h-2/3 min-h-96 max-h-dvh w-full border border-gray-300 rounded-lg items-center"></div>
      <input type="hidden" name="code" id="code-input">
    </span>
    """
  end
end
