defmodule TrySyndicateWeb.CodeMirrorComponent do
  use TrySyndicateWeb, :live_component

  def render(assigns) do
    ~H"""
      <div id={@id} phx-hook="CodeMirror"
       class="h-fit w-full border border-gray-300 rounded-lg items-center"></div>
    """
  end
end
