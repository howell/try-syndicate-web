defmodule TrySyndicate.Syndicate.Actor do
  @moduledoc """
  This module defines the data used to represent an actor.
  """

  alias TrySyndicate.Syndicate.Core

  @type t() :: %__MODULE__{
          name: String.t(),
          assertions: Core.trie()
        }

  defstruct [
    :name,
    :assertions
  ]

  @spec from_json(term()) :: t() | nil
  def from_json(json) do
    if is_map(json) && is_binary(json["name"]) && json["assertions"] do
      name = json["name"]
      assertions = Core.json_to_trie(json["assertions"])
      if assertions, do: %__MODULE__{name: name, assertions: assertions}, else: nil
    else
      nil
    end
  end
end
