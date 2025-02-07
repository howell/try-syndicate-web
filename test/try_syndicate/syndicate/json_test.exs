defmodule TrySyndicate.Syndicate.JsonTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.Syndicate.{Dataspace, Actor, SpaceTime, Core}

  describe "Dataspace.from_json/1 on real examples" do
    test "parses JSON with no actors and pending actions" do
      json = %{
        "active_actor" => false,
        "actors" => [],
        "pending_actions" => [
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(observe #s(outbound ★))",
                  "'#s(observe #s(observe #s(inbound ★)))"
                ],
                "removed" => []
              }
            ],
            "origin" => %{"space" => "(meta)", "time" => 10564}
          }
        ],
        "recent_messages" => [],
        "last_op" => false
      }

      assert {:ok, dataspace} = Dataspace.from_json(json)
      assert dataspace.active_actor == :none
      assert dataspace.actors == %{}
      assert length(dataspace.pending_actions) == 1
      assert dataspace.recent_messages == []
      assert dataspace.last_op == false
    end

    test "parses JSON with actors and pending actions" do
      json = %{
        "active_actor" => false,
        "actors" => [
          %{"assertions" => [], "id" => "(0)", "name" => "#f"}
        ],
        "pending_actions" => [
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(stay-up command-handler)",
                  "'#s(observe #s(up command-handler))",
                  "'#s(up repl-supervisor)"
                ],
                "removed" => []
              },
              [
                "spawn",
                [
                  "'#s(observe #s(stay-up command-handler))",
                  "'#s(observe #s(up repl-supervisor))",
                  "'#s(up command-handler)"
                ]
              ],
              %{
                "added" => ["'#s(observe flush!907886)"],
                "removed" => []
              },
              ["message", "'#s(message flush!907886)"]
            ],
            "origin" => %{"space" => "(0)", "time" => 10566}
          },
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(observe #s(outbound ★))",
                  "'#s(observe #s(observe #s(inbound ★)))"
                ],
                "removed" => []
              }
            ],
            "origin" => %{"space" => "(meta)", "time" => 10564}
          }
        ],
        "recent_messages" => [],
        "last_op" => "action-interpreted"
      }

      assert {:ok, dataspace} = Dataspace.from_json(json)
      assert dataspace.active_actor == :none
      assert map_size(dataspace.actors) == 1
      assert length(dataspace.pending_actions) == 2
      assert dataspace.recent_messages == []
      assert dataspace.last_op == "action-interpreted"
    end

    test "parses JSON with actors and pending actions (without data key)" do
      json = %{
        "active_actor" => false,
        "actors" => [
          %{"assertions" => [], "id" => "(0)", "name" => "#f"}
        ],
        "pending_actions" => [
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(stay-up command-handler)",
                  "'#s(observe #s(up command-handler))",
                  "'#s(up repl-supervisor)"
                ],
                "removed" => []
              },
              [
                "spawn",
                [
                  "'#s(observe #s(stay-up command-handler))",
                  "'#s(observe #s(up repl-supervisor))",
                  "'#s(up command-handler)"
                ]
              ],
              %{
                "added" => ["'#s(observe flush!907886)"],
                "removed" => []
              },
              ["message", "'#s(message flush!907886)"]
            ],
            "origin" => %{"space" => "(0)", "time" => 10566}
          },
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(observe #s(outbound ★))",
                  "'#s(observe #s(observe #s(inbound ★)))"
                ],
                "removed" => []
              }
            ],
            "origin" => %{"space" => "(meta)", "time" => 10564}
          }
        ],
        "recent_messages" => [],
        "last_op" => "spawn-actor"
      }

      assert {:ok, dataspace} = Dataspace.from_json(json)
      assert dataspace.active_actor == :none
      assert map_size(dataspace.actors) == 1
      assert length(dataspace.pending_actions) == 2
      assert dataspace.recent_messages == []
      assert dataspace.last_op == "spawn-actor"
    end
  end

  describe "Dataspace.from_json/1" do
    test "returns error for invalid JSON" do
      assert {:error, _} = Dataspace.from_json(%{})
    end

    test "parses basic valid JSON with no actors" do
      json = %{
        "active_actor" => false,
        "actors" => [],
        "pending_actions" => [
          %{
            "actions" => [%{"added" => ["a"], "removed" => []}],
            "origin" => %{"space" => "(meta)", "time" => 100}
          }
        ],
        "recent_messages" => [],
        "last_op" => false
      }
      assert {:ok, dataspace} = Dataspace.from_json(json)
      assert dataspace.active_actor == :none
      assert dataspace.actors == %{}
      assert length(dataspace.pending_actions) == 1
      assert dataspace.recent_messages == []
      assert dataspace.last_op == false
    end
  end

  describe "Dataspace.parse_actors/1" do
    test "returns empty map for empty list" do
      assert Dataspace.parse_actors([]) == {:ok, %{}}
    end

    test "returns error for invalid actor data" do
      assert {:error, _} = Dataspace.parse_actors(["invalid"])
    end

    test "parses valid actor JSON" do
      actor_json = %{"id" => "1", "name" => "Test", "assertions" => ["a", "b"]}
      assert {:ok, actors} = Dataspace.parse_actors([actor_json])
      assert is_map(actors)
      assert Map.has_key?(actors, "1")
    end
  end

  describe "Dataspace.parse_active_actor/1" do
    test "returns :none when false" do
      assert {:ok, :none} = Dataspace.parse_active_actor(false)
    end

    test "parses valid active actor JSON" do
      event_json = %{"actor" => "1", "event" => ["message", "ok"], "actions" => false}
      assert {:ok, active} = Dataspace.parse_active_actor(event_json)
      assert active == {"1", {:message, "ok"}, false}
    end

    test "returns error for incomplete active actor JSON" do
      assert {:error, _} = Dataspace.parse_active_actor(%{})
    end
  end

  describe "Dataspace.parse_recent_messages/1" do
    test "parses valid list of strings" do
      msgs = [["message", "hello"], ["message", "world"]]
      assert {:ok, result} = Dataspace.parse_recent_messages(msgs)
      assert result == [{:message, "hello"}, {:message, "world"}]
    end

    test "returns error for list with non-string elements" do
      assert {:error, _} = Dataspace.parse_recent_messages([1, 2])
    end
  end

  describe "Dataspace.parse_pending_acts/1" do
    test "parses valid pending actions" do
      action_json = %{
        "actions" => [%{"added" => ["a"], "removed" => []}],
        "origin" => %{"space" => "(meta)", "time" => 123}
      }
      assert {:ok, acts} = Dataspace.parse_pending_acts([action_json])
      assert is_list(acts)
      [{space_time, actions}] = acts
      assert space_time == %SpaceTime{space: "(meta)", time: 123}
      # actions should be a list of parsed actions (e.g. patch tuples)
      assert is_tuple(hd(actions))
    end

    test "returns error for invalid pending actions" do
      assert {:error, _} = Dataspace.parse_pending_acts("invalid")
    end
  end

  # SpaceTime.from_json
  describe "SpaceTime.from_json/1" do
    test "parses valid space_time JSON" do
      json = %{"space" => "(meta)", "time" => 123}
      assert {:ok, st} = SpaceTime.from_json(json)
      assert st == %SpaceTime{space: "(meta)", time: 123}
    end

    test "returns error for non-integer time" do
      assert {:error, _} = SpaceTime.from_json(%{"space" => "(meta)", "time" => "not_int"})
    end
  end

  # Actor.from_json
  describe "Actor.from_json/1" do
    test "parses valid actor JSON" do
      json = %{"id" => "1", "name" => "Actor1", "assertions" => ["x", "y"]}
      assert {:ok, actor} = Actor.from_json(json)
      assert actor.name == "Actor1"
      assert actor.assertions == ["x", "y"]
    end

    test "returns error if required fields are missing" do
      assert {:error, _} = Actor.from_json(%{"name" => "Actor1"})
    end
  end

  # Core module parsers
  describe "Core.json_to_trie/1" do
    test "parses valid trie list" do
      assert {:ok, result} = Core.json_to_trie(["a", "b"])
      assert result == ["a", "b"]
    end

    test "returns error for invalid trie" do
      assert {:error, _} = Core.json_to_trie("invalid")
    end
  end

  describe "Core.json_to_patch/1" do
    test "parses valid patch JSON" do
      patch_json = %{"added" => ["a"], "removed" => ["b"]}
      assert {:ok, result} = Core.json_to_patch(patch_json)
      assert result == {["a"], ["b"]}
    end

    test "returns error for patch with non-list values" do
      assert {:error, _} = Core.json_to_patch(%{"added" => "a", "removed" => "b"})
    end
  end

  describe "Core.json_to_spawn/1" do
    test "parses valid spawn JSON" do
      spawn_json = ["spawn", ["assert1"]]
      assert {:ok, result} = Core.json_to_spawn(spawn_json)
      assert result == {:spawn, ["assert1"]}
    end

    test "returns error for spawn JSON missing assertions" do
      assert {:error, _} = Core.json_to_spawn(["spawn", "spawn"])
    end
  end

  describe "Core.json_to_quit/1" do
    test "parses 'quit' correctly" do
      assert {:ok, :quit} = Core.json_to_quit("quit")
    end

    test "returns error for non-'quit' strings" do
      assert {:error, _} = Core.json_to_quit("continue")
    end
  end

  describe "Core.json_to_message/1" do
    test "parses valid message array" do
      msg = ["message", "hello"]
      assert {:ok, result} = Core.json_to_message(msg)
      assert result == {:message, "hello"}
    end

    test "returns error for invalid message format" do
      assert {:error, _} = Core.json_to_message(["not", "message"])
    end
  end

  describe "Core.json_to_action/1" do
    test "parses quit action" do
      assert {:ok, :quit} = Core.json_to_action("quit")
    end

    test "parses message action" do
      msg = ["message", "test"]
      assert {:ok, result} = Core.json_to_action(msg)
      assert result == {:message, "test"}
    end

    test "parses spawn action" do
      spawn_json = ["spawn", ["assert"]]
      assert {:ok, result} = Core.json_to_action(spawn_json)
      assert result == {:spawn, ["assert"]}
    end

    test "parses patch action" do
      patch_json = %{"added" => ["a"], "removed" => ["b"]}
      assert {:ok, result} = Core.json_to_action(patch_json)
      assert result == {["a"], ["b"]}
    end

    test "returns error for invalid action" do
      assert {:error, _} = Core.json_to_action(123)
    end
  end

  describe "Core.json_to_event/1" do
    test "parses false as false" do
      assert {:ok, false} = Core.json_to_event(false)
    end

    test "parses message event" do
      msg = ["message", "event"]
      assert {:ok, result} = Core.json_to_event(msg)
      assert result == {:message, "event"}
    end

    test "parses patch event" do
      patch_json = %{"added" => ["a"], "removed" => ["b"]}
      assert {:ok, result} = Core.json_to_event(patch_json)
      assert result == {["a"], ["b"]}
    end
  end
end
