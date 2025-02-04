defmodule TrySyndicate.Syndicate.JsonTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.Syndicate.Dataspace

  describe "Dataspace.from_json/1" do
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
        "recent_messages" => []
      }

      dataspace = Dataspace.from_json(json)
      assert dataspace != nil
      assert dataspace.active_actor == :none
      assert dataspace.actors == %{}
      assert length(dataspace.pending_acts) == 1
      assert dataspace.recent_messages == []
    end

    test "parses JSON with actors and pending actions" do
      json = %{
        "data" => %{
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
                %{
                  "initial_assertions" => [
                    "'#s(observe #s(stay-up command-handler))",
                    "'#s(observe #s(up repl-supervisor))",
                    "'#s(up command-handler)"
                  ],
                  "type" => "spawn"
                },
                %{
                  "added" => ["'#s(observe flush!907886)"],
                  "removed" => []
                },
                "'#s(message flush!907886)"
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
          "recent_messages" => []
        }
      }

      dataspace = Dataspace.from_json(json)
      assert dataspace != nil
      assert dataspace.active_actor == :none
      assert length(dataspace.actors) == 1
      assert length(dataspace.pending_acts) == 2
      assert dataspace.recent_messages == []
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
              %{
                "initial_assertions" => [
                  "'#s(observe #s(stay-up command-handler))",
                  "'#s(observe #s(up repl-supervisor))",
                  "'#s(up command-handler)"
                ],
                "type" => "spawn"
              },
              %{
                "added" => ["'#s(observe flush!907886)"],
                "removed" => []
              },
              "'#s(message flush!907886)"
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
        "recent_messages" => []
      }

      dataspace = Dataspace.from_json(json)
      assert dataspace != nil
      assert dataspace.active_actor == :none
      assert length(dataspace.actors) == 1
      assert length(dataspace.pending_acts) == 2
      assert dataspace.recent_messages == []
    end
  end
end
