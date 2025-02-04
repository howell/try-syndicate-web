defmodule TrySyndicate.Syndicate.Core do
  @type trie() :: [String.t()]
  @type patch() :: {trie(), trie()}
  @type spawn() :: {:spawn, trie()}
  @type message() :: {:message, term()}
  @type action() :: patch() | :quit | spawn() | message()
  @type event() :: patch() | message() | false

  @spec json_to_trie(term()) :: trie() | nil
  def json_to_trie(json) do
    cond do
      is_list(json) and Enum.all?(json, &is_binary/1) ->
        json

      true ->
        nil
    end
  end

  @spec json_to_patch(term()) :: patch() | nil
  def json_to_patch(json) do
    cond do
      is_map(json) && json["added"] && json["removed"] ->
        added = json_to_trie(json["added"])
        removed = json_to_trie(json["removed"])
        added && removed && {added, removed}

      true ->
        nil
    end
  end

  @spec json_to_spawn(term()) :: spawn() | nil
  def json_to_spawn(json) do
    cond do
      is_map(json) && json["type"] == "spawn" && json["initial_assertions"] ->
        trie = json_to_trie(json["initial_assertions"])
        trie && {:spawn, trie}

      true ->
        nil
    end
  end

  @spec json_to_quit(term()) :: :quit | nil
  def json_to_quit(json) do
    if json == "quit" do
      :quit
    else
      nil
    end
  end

  @spec json_to_message(term()) :: message() | nil
  def json_to_message(json) do
    if is_list(json) and length(json) == 2 and json[0] == "message" do
      {:message, json[1]}
    else
      nil
    end
  end

  @spec json_to_action(term()) :: action() | nil
  def json_to_action(json) do
    json_to_quit(json) || json_to_message(json) || json_to_spawn(json) || json_to_patch(json)
  end

  @spec json_to_event(term()) :: event() | nil
  def json_to_event(json) do
    if json == false do
      false
    else
      json_to_message(json) || json_to_patch(json)
    end
  end
end
