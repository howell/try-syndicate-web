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
end
