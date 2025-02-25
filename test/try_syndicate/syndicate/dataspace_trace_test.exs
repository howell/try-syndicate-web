defmodule TrySyndicate.Syndicate.DataspaceTraceTest do
  use ExUnit.Case, async: true
  alias TrySyndicate.Syndicate.{DataspaceTrace, Dataspace, Actor, ActorEnv, TraceNotification}

  describe "all_unfiltered_actors/1" do
    test "returns empty list for empty trace" do
      trace = DataspaceTrace.new()
      assert DataspaceTrace.all_unfiltered_actors(trace) == []
    end

    test "returns all actors from filtered dataspaces" do
      # Create a trace with some actors
      actor1 = %Actor{name: "actor1", assertions: []}
      actor2 = %Actor{name: "actor2", assertions: []}

      actor_id1 = "actor_id_1"
      actor_id2 = "actor_id_2"

      dataspace = %Dataspace{
        actors: %{actor_id1 => actor1, actor_id2 => actor2},
        active_actor: :none,
        recent_messages: [],
        pending_actions: [],
        last_op: false
      }

      trace = DataspaceTrace.new()
      trace = DataspaceTrace.add_step(trace, dataspace)

      # Get all unfiltered actors
      actors = DataspaceTrace.all_unfiltered_actors(trace)

      # Should contain both actors
      assert length(actors) == 2
      assert Enum.any?(actors, fn {id, _} -> id == actor_id1 end)
      assert Enum.any?(actors, fn {id, _} -> id == actor_id2 end)
    end

    test "respects filtering" do
      # Create actors
      actor1 = %Actor{name: "actor1", assertions: []}
      actor2 = %Actor{name: "actor2", assertions: []}

      actor_id1 = "actor_id_1"
      actor_id2 = "actor_id_2"

      dataspace = %Dataspace{
        actors: %{actor_id1 => actor1, actor_id2 => actor2},
        active_actor: :none,
        recent_messages: [],
        pending_actions: [],
        last_op: false
      }

      # Create trace with filter on actor1
      filter = %{names: ["actor1"], pids: []}
      trace = DataspaceTrace.new(filter)
      trace = DataspaceTrace.add_step(trace, dataspace)

      # Should only contain actor2
      actors = DataspaceTrace.all_unfiltered_actors(trace)
      assert length(actors) == 1
      assert Enum.any?(actors, fn {id, _} -> id == actor_id2 end)
      refute Enum.any?(actors, fn {id, _} -> id == actor_id1 end)
    end
  end

  describe "all_actors/1" do
    test "returns all actors regardless of filtering" do
      # Create actors
      actor1 = %Actor{name: "actor1", assertions: []}
      actor2 = %Actor{name: "actor2", assertions: []}

      actor_id1 = "actor_id_1"
      actor_id2 = "actor_id_2"

      dataspace = %Dataspace{
        actors: %{actor_id1 => actor1, actor_id2 => actor2},
        active_actor: :none,
        recent_messages: [],
        pending_actions: [],
        last_op: false
      }

      # Create trace with filter on actor1
      filter = %{names: ["actor1"], pids: []}
      trace = DataspaceTrace.new(filter)
      trace = DataspaceTrace.add_step(trace, dataspace)

      # Should contain both actors
      actors = DataspaceTrace.all_actors(trace)
      assert length(actors) == 2
      assert Enum.any?(actors, fn {id, _} -> id == actor_id1 end)
      assert Enum.any?(actors, fn {id, _} -> id == actor_id2 end)
    end
  end
end
