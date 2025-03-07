defmodule TrySyndicateWeb.FacetTreeTest do
  use ExUnit.Case, async: true
  alias TrySyndicateWeb.FacetTreeComponent
  setup do
    actor = %TrySyndicate.Syndicate.ActorDetail{
      facets: %{
        "(256)" => %TrySyndicate.Syndicate.Facet{
          id: "(256)",
          fields: [
            %TrySyndicate.Syndicate.Field{
              name: "x",
              id: "104",
              value: "0",
              src: %TrySyndicate.Syndicate.Srcloc{
                source: "0",
                line: 1,
                column: 15,
                position: 16,
                span: 1
              }
            }
          ],
          eps: [],
          children: ["(257 256)"]
        },
        "(257 256)" => %TrySyndicate.Syndicate.Facet{
          id: "(257 256)",
          fields: [],
          eps: [
            %TrySyndicate.Syndicate.Endpoint{
              description: "(assert (x))",
              src: %TrySyndicate.Syndicate.Srcloc{
                source: "0",
                line: 1,
                column: 38,
                position: 39,
                span: 12
              },
              id: "0"
            }
          ],
          children: []
        }
      },
      dataflow: %{"104" => [{"(257 256)", "0"}]}
    }
    %{actor: actor}
  end

  test "find_field_position returns the correct position", %{actor: actor} do
    assert {"(256)", 25.0} = FacetTreeComponent.find_field_position(actor.facets, "104", 10)
  end

  test "dataflow edges are computed correctly", %{actor: actor} do
    dataflow_edges = FacetTreeComponent.extract_dataflow_edges(actor.dataflow, actor.facets)
    assert [{"(256)", "(257 256)", _, _, "0"}] = dataflow_edges
  end
end
