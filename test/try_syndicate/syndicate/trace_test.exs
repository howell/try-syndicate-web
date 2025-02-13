defmodule TrySyndicate.TraceTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.Syndicate.{Dataspace, DataspaceTrace, Actor, SpaceTime, Core}

  describe "Creating an empty trace then adding first step" do
    test "add_step/2 adds a step to the trace" do
      ds_json = %{
        "active_actor" => %{"actions" => false, "actor" => "(0)", "event" => "boot"},
        "actors" => [%{"assertions" => [], "id" => "(0)", "name" => "repl-supervisor"}],
        "last_op" => "spawn-actor",
        "pending_actions" => [],
        "recent_messages" => []
      }

      {:ok, ds} = Dataspace.from_json(ds_json)

      filter = %{
        names: ["repl-supervisor", "drivers/repl", "drivers/timer", "drivers/timestate"],
        pids: ["()", "(meta)"]
      }

      trace = DataspaceTrace.new(filter)

      trace = DataspaceTrace.add_step(trace, ds)

      assert map_size(trace.trace) == 1
      assert map_size(trace.filtered) == 1
    end
  end
end
