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

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    cond do
      not is_map(json) ->
        {:error, "Expected a map"}

      not is_binary(json["name"]) ->
        {:error, "Missing or invalid 'name'"}

      not Map.has_key?(json, "assertions") ->
        {:error, "Missing 'assertions'"}

      true ->
        with {:ok, assertions} <- Core.json_to_trie(json["assertions"]) do
          {:ok, %__MODULE__{name: json["name"], assertions: assertions}}
        else
          {:error, reason} -> {:error, "Invalid assertions: " <> reason}
        end
    end
  end
end
