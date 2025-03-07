defmodule TrySyndicate.TraceTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.Syndicate.{Dataspace, DataspaceTrace}

  setup do
    raw_trace_jsons = [
      %{
        "active_actor" => %{"actions" => false, "actor" => "(0)", "event" => "boot"},
        "actors" => [%{"assertions" => [], "id" => "(0)", "name" => "repl-supervisor"}],
        "last_op" => "spawn-actor",
        "pending_actions" => []
      },
      %{
        "active_actor" => %{
          "actions" => [
            %{
              "added" => [
                "'#s(up repl-supervisor)",
                "'#s(observe #s(up command-handler))",
                "'#s(stay-up command-handler)"
              ],
              "removed" => []
            },
            [
              "spawn",
              [
                "'#s(up command-handler)",
                "'#s(observe #s(up repl-supervisor))",
                "'#s(observe #s(stay-up command-handler))"
              ]
            ],
            %{"added" => ["'#s(observe flush!2760184)"], "removed" => []},
            ["message", "'#s(message flush!2760184)"]
          ],
          "actor" => "(0)",
          "event" => "boot"
        },
        "actors" => [%{"assertions" => [], "id" => "(0)", "name" => "repl-supervisor"}],
        "last_op" => "actions-produced",
        "pending_actions" => [
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(up repl-supervisor)",
                  "'#s(observe #s(up command-handler))",
                  "'#s(stay-up command-handler)"
                ],
                "removed" => []
              },
              [
                "spawn",
                [
                  "'#s(up command-handler)",
                  "'#s(observe #s(up repl-supervisor))",
                  "'#s(observe #s(stay-up command-handler))"
                ]
              ],
              %{"added" => ["'#s(observe flush!2760184)"], "removed" => []},
              ["message", "'#s(message flush!2760184)"]
            ],
            "origin" => %{"space" => "(0)", "time" => 33517}
          }
        ]
      },
      %{
        "active_actor" => false,
        "actors" => [%{"assertions" => [], "id" => "(0)", "name" => "repl-supervisor"}],
        "last_op" => "action-interpreted",
        "pending_actions" => [
          %{
            "actions" => [
              %{
                "added" => [
                  "'#s(up repl-supervisor)",
                  "'#s(observe #s(up command-handler))",
                  "'#s(stay-up command-handler)"
                ],
                "removed" => []
              },
              [
                "spawn",
                [
                  "'#s(up command-handler)",
                  "'#s(observe #s(up repl-supervisor))",
                  "'#s(observe #s(stay-up command-handler))"
                ]
              ],
              %{"added" => ["'#s(observe flush!2760184)"], "removed" => []},
              ["message", "'#s(message flush!2760184)"]
            ],
            "origin" => %{"space" => "(0)", "time" => 33517}
          }
        ]
      }
    ]

    steps =
      Enum.map(raw_trace_jsons, fn raw_trace_json ->
        {:ok, ds} = Dataspace.from_json(raw_trace_json)
        ds
      end)

    step_map =
      for {step, idx} <- Enum.with_index(steps), into: %{} do
        {idx, step}
      end

    {:ok, raw_trace_jsons: raw_trace_jsons, steps: steps, step_map: step_map}
  end

  describe "Creating an empty trace then adding first step" do
    test "add_step/2 adds a step to the trace" do
      ds_json = %{
        "active_actor" => %{"actions" => false, "actor" => "(0)", "event" => "boot"},
        "actors" => [%{"assertions" => [], "id" => "(0)", "name" => "repl-supervisor"}],
        "last_op" => "spawn-actor",
        "pending_actions" => []
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

  describe "Creating a filtered trace all at once" do
    test "apply_filter", %{steps: steps} do
      filter = %{
        names: ["repl-supervisor", "drivers/repl", "drivers/timer", "drivers/timestate"],
        pids: ["()", "(meta)"]
      }

      one_by_one =
        Enum.reduce(steps, DataspaceTrace.new(filter), fn ds, trace ->
          DataspaceTrace.add_step(trace, ds)
        end)

      assert map_size(one_by_one.trace) == 3
      assert map_size(one_by_one.filtered) == 1

      assert one_by_one.filtered == %{
               0 =>
                 {%Dataspace{
                    active_actor: :none,
                    actors: %{},
                    last_op: "spawn-actor",
                    pending_actions: []
                  }, 0}
             }

      all_together = DataspaceTrace.apply_filter(one_by_one.trace, filter)
      assert map_size(all_together.trace) == 3
      assert map_size(all_together.filtered) == 1
      assert all_together.filtered == one_by_one.filtered
    end
  end

  describe "remove a filtered actor using update_filter" do
    test "update_filter", %{step_map: steps} do
      filter = %{
        names: ["repl-supervisor", "drivers/repl", "drivers/timer", "drivers/timestate"],
        pids: ["()", "(meta)"]
      }

      trace = DataspaceTrace.apply_filter(steps, filter)
      new_filter = %{
        names: ["drivers/repl", "drivers/timer", "drivers/timestate"],
        pids: ["()", "(meta)"]
      }
      {new_trace, new_idx} = DataspaceTrace.update_filter(trace, new_filter, 0)
      assert map_size(new_trace.trace) == map_size(trace.trace)
      assert map_size(new_trace.filtered) == 3
      assert new_idx == 0
    end
  end
end
