defmodule TrySyndicate.Syndicate.Core do
  @type trie() :: [String.t()]
  @type patch() :: {trie(), trie()}
  @type action() :: patch() | :quit | any()
end
