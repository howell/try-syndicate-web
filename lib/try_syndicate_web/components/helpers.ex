defmodule TrySyndicateWeb.Components.Helpers do
  use Phoenix.Component

  def code_mirror_line(assigns) do
    ~H"""
        <div class="flex flex-row justify-between mt-4 px-2">
          <div class="w-4 min-w-4 mr-2">
            <%= @label %>
          </div>
         <div class="w-3/4">
           <%= live_component %{module: TrySyndicateWeb.CodeMirrorComponent, id: @id, content: @content, active: @active }%>
         </div>
         <div class="w-1/4 ml-2">
           <pre><%= @output %></pre>
         </div>
      </div>
    """
  end
end
