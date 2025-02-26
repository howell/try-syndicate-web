defmodule TrySyndicate.Syndicate.DataspaceTraceTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.Syndicate.{
    DataspaceTrace,
    Dataspace,
    Actor,
    ActorEnv,
    TraceNotification,
    Core
  }

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

  describe "actor listing functions" do
    test "all_actors/1 returns list of tuples with actor id and name" do
      # Create actors with names
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

      # Create a trace with the dataspace
      trace = %{
        trace: %{0 => dataspace},
        filter: %{names: [], pids: []},
        filtered: %{},
        actors: %{}
      }

      # Get all actors
      actors = DataspaceTrace.all_actors(trace)

      # Check the structure of the result
      assert is_list(actors)
      assert length(actors) == 2

      # Each entry should be a tuple with {actor_id, actor_name}
      Enum.each(actors, fn actor_tuple ->
        assert is_tuple(actor_tuple)
        assert tuple_size(actor_tuple) == 2
      end)

      # Verify specific actor entries
      assert Enum.any?(actors, fn {id, name} -> id == actor_id1 && name == "actor1" end)
      assert Enum.any?(actors, fn {id, name} -> id == actor_id2 && name == "actor2" end)
    end

    test "all_unfiltered_actors/1 returns list of tuples with actor id and name" do
      # Create actors with names
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

      # Create a trace with filtered dataspace
      trace = %{
        trace: %{},
        filter: %{names: [], pids: []},
        filtered: %{0 => {dataspace, 0}},
        actors: %{}
      }

      # Get all unfiltered actors
      actors = DataspaceTrace.all_unfiltered_actors(trace)

      # Check the structure of the result
      assert is_list(actors)
      assert length(actors) == 2

      # Each entry should be a tuple with {actor_id, actor_name}
      Enum.each(actors, fn actor_tuple ->
        assert is_tuple(actor_tuple)
        assert tuple_size(actor_tuple) == 2
      end)

      # Verify specific actor entries
      assert Enum.any?(actors, fn {id, name} -> id == actor_id1 && name == "actor1" end)
      assert Enum.any?(actors, fn {id, name} -> id == actor_id2 && name == "actor2" end)
    end
  end

  describe "actor step navigation" do
    setup do
      # Create a trace with multiple steps and actors
      actor1 = %Actor{name: "actor1", assertions: []}
      actor2 = %Actor{name: "actor2", assertions: []}
      actor_id1 = "actor_id_1"
      actor_id2 = "actor_id_2"

      # Create dataspaces with different actor states
      ds0 = %Dataspace{
        actors: %{actor_id1 => actor1},
        active_actor: :none,
        recent_messages: [],
        pending_actions: [],
        last_op: false
      }

      ds1 = %Dataspace{
        actors: %{actor_id1 => actor1, actor_id2 => actor2},
        active_actor: {actor_id2, false, false},
        recent_messages: [],
        pending_actions: [],
        last_op: false
      }

      ds2 = %Dataspace{
        actors: %{actor_id1 => actor1, actor_id2 => actor2},
        active_actor: :none,
        recent_messages: [],
        pending_actions: [],
        last_op: false
      }

      # Create trace with these steps
      # Raw Idx | Filtered Idx
      trace =
        DataspaceTrace.new()
        # 0 | 0
        |> DataspaceTrace.add_step(ds0)
        # 1 | 1
        |> DataspaceTrace.add_step(ds1)
        # 2 | 2
        |> DataspaceTrace.add_step(ds2)
        # 3 |     this step will be elided from the filtered trace
        |> DataspaceTrace.add_step(ds2)
        # 4 | 3
        |> DataspaceTrace.add_step(ds0)

      # Add actor environments
      trace = %{
        trace
        | actors: %{
            0 => %{actor_id1 => %{state: "state1"}},
            1 => %{actor_id1 => %{state: "state1"}, actor_id2 => %{state: "state2"}},
            2 => %{actor_id1 => %{state: "state1"}, actor_id2 => %{state: "state3"}},
            4 => %{actor_id1 => %{state: "state4"}}
          }
      }

      {:ok, trace: trace, actor_id1: actor_id1, actor_id2: actor_id2}
    end

    test "actor_trace/2 returns raw steps where actor exists with a distinct state", %{
      trace: trace,
      actor_id1: actor_id1,
      actor_id2: actor_id2
    } do
      assert DataspaceTrace.actor_trace(trace, actor_id1) == [0, 4]
      assert DataspaceTrace.actor_trace(trace, actor_id2) == [1, 2]
      assert DataspaceTrace.actor_trace(trace, "nonexistent") == []
    end

    test "first_actor_step/2 returns first filtered step where actor exists", %{
      trace: trace,
      actor_id1: actor_id1,
      actor_id2: actor_id2
    } do
      assert DataspaceTrace.first_actor_step(trace, actor_id1) == 0
      assert DataspaceTrace.first_actor_step(trace, actor_id2) == 1
      assert DataspaceTrace.first_actor_step(trace, "nonexistent") == nil
    end

    test "last_actor_step/2 returns last filtered step where actor exists with a distinct state",
         %{trace: trace, actor_id1: actor_id1, actor_id2: actor_id2} do
      assert DataspaceTrace.last_actor_step(trace, actor_id1) == 3
      assert DataspaceTrace.last_actor_step(trace, actor_id2) == 2
      assert DataspaceTrace.last_actor_step(trace, "nonexistent") == nil
    end

    test "next_actor_step/3 returns next filtered step where actor exists with a distinct state",
         %{trace: trace, actor_id1: actor_id1, actor_id2: actor_id2} do
      assert DataspaceTrace.next_actor_step(trace, actor_id1, 0) == 3
      assert DataspaceTrace.next_actor_step(trace, actor_id2, 1) == 2
      assert DataspaceTrace.next_actor_step(trace, actor_id1, 1) == 3
      assert DataspaceTrace.next_actor_step(trace, "nonexistent", 0) == nil
    end

    test "prev_actor_step/3 returns previous filtered step where actor exists with a distinct state",
         %{trace: trace, actor_id1: actor_id1, actor_id2: actor_id2} do
      assert DataspaceTrace.prev_actor_step(trace, actor_id1, 2) == nil
      assert DataspaceTrace.prev_actor_step(trace, actor_id2, 1) == nil
      assert DataspaceTrace.prev_actor_step(trace, actor_id1, 3) == 0
      assert DataspaceTrace.prev_actor_step(trace, "nonexistent", 1) == nil
    end

    test "actor_step_count/2 returns number of steps where actor exists", %{
      trace: trace,
      actor_id1: actor_id1,
      actor_id2: actor_id2
    } do
      assert DataspaceTrace.actor_step_count(trace, actor_id1) == 2
      assert DataspaceTrace.actor_step_count(trace, actor_id2) == 2
      assert DataspaceTrace.actor_step_count(trace, "nonexistent") == 0
    end

    test "actor_step_idx/3 returns index of step in actor's timeline", %{
      trace: trace,
      actor_id1: actor_id1,
      actor_id2: actor_id2
    } do
      # Test actor1's timeline
      assert DataspaceTrace.actor_step_idx(trace, actor_id1, 0) == 0
      assert DataspaceTrace.actor_step_idx(trace, actor_id1, 1) == 0
      assert DataspaceTrace.actor_step_idx(trace, actor_id1, 2) == 0
      assert DataspaceTrace.actor_step_idx(trace, actor_id1, 3) == 1

      # Test actor2's timeline
      assert DataspaceTrace.actor_step_idx(trace, actor_id2, 0) == nil
      assert DataspaceTrace.actor_step_idx(trace, actor_id2, 1) == 0
      assert DataspaceTrace.actor_step_idx(trace, actor_id2, 2) == 1
      assert DataspaceTrace.actor_step_idx(trace, actor_id2, 3) == 1

      # Test nonexistent actor
      assert DataspaceTrace.actor_step_idx(trace, "nonexistent", 0) == nil
    end
  end
end
