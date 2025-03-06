defmodule TrySyndicate.Syndicate.TraceNotificationTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.Syndicate.TraceNotification

  describe "trace notification from json" do
    test "decode simple actors notification" do
      json = %{
        "detail" => [%{"actor_id" => "(0)", "detail" => %{"facets" => [], "dataflow" => []}}],
        "type" => "actors"
      }

      result = TraceNotification.from_json(json)
      assert {:ok, %TraceNotification{type: :actors}} = result
    end

    test "decode dataspace notification" do
      json = %{
        "detail" => %{
          "active_actor" => %{
            "actions" => [
              %{
                "added" => [
                  "'#s(observe #s(up repl-supervisor))",
                  "'#s(observe #s(stay-up command-handler))",
                  "'#s(up command-handler)"
                ],
                "removed" => []
              }
            ],
            "actor" => "(1)",
            "event" => "boot"
          },
          "actors" => [
            %{
              "assertions" => [
                "'#s(observe #s(up command-handler))",
                "'#s(up repl-supervisor)",
                "'#s(stay-up command-handler)"
              ],
              "id" => "(0)",
              "name" => "repl-supervisor"
            },
            %{"assertions" => [], "id" => "(1)", "name" => "drivers/repl"}
          ],
          "last_op" => "actions-produced",
          "pending_actions" => [
            %{
              "actions" => [
                %{
                  "added" => [
                    "'#s(observe #s(up repl-supervisor))",
                    "'#s(observe #s(stay-up command-handler))",
                    "'#s(up command-handler)"
                  ],
                  "removed" => []
                }
              ],
              "origin" => %{"space" => "(1)", "time" => 257}
            },
            %{
              "actions" => [
                %{"added" => ["'#s(observe flush!24476)"], "removed" => []},
                ["message", "'#s(message flush!24476)"]
              ],
              "origin" => %{"space" => "(0)", "time" => 246}
            }
          ],
          "recent_messages" => []
        },
        "type" => "dataspace"
      }

      result = TraceNotification.from_json(json)
      assert {:ok, %TraceNotification{type: :dataspace}} = result
    end
  end
end
