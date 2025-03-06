defmodule TrySyndicate.Syndicate.ActorJsonTest do
  use ExUnit.Case, async: true

  alias Jason
  alias TrySyndicate.Syndicate.{ActorEnv, Facet, Field, Endpoint, Srcloc, ActorDetail}

  describe "srcloc fromjson basic" do
    test "srcloc fromjson" do
      raw_json = "{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10}"
      srcloc_json = Jason.decode!(raw_json)

      result = Srcloc.from_json(srcloc_json)

      assert {:ok,
              %Srcloc{
                column: 5,
                line: 1,
                position: 50,
                source: "test.rkt",
                span: 10
              }} == result
    end
  end

  describe "endpoint fromjson basic" do
    test "endpoint fromjson" do
      raw_json =
        "{\"description\":\"'(assert 'hello)\",\"id\":\"test\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10}}"

      endpoint_json = Jason.decode!(raw_json)

      result = Endpoint.from_json(endpoint_json)

      assert {:ok,
              %Endpoint{
                description: "'(assert 'hello)",
                id: "test",
                src: %Srcloc{
                  column: 5,
                  line: 1,
                  position: 50,
                  source: "test.rkt",
                  span: 10
                }
              }} == result
    end
  end

  describe "field fromjson basic" do
    test "field fromjson" do
      raw_json =
        "{\"name\":\"test\",\"id\":\"10\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10},\"value\":1234}"

      field_json = Jason.decode!(raw_json)

      result = Field.from_json(field_json)

      assert {:ok,
              %Field{
                name: "test",
                id: "10",
                src: %Srcloc{
                  column: 5,
                  line: 1,
                  position: 50,
                  source: "test.rkt",
                  span: 10
                },
                value: 1234
              }} == result
    end
  end

  describe "facet fromjson basic" do
    test "facet fromjson" do
      raw_json =
        "{\"children\":[\"child1\",\"child2\"],\"endpoints\":[],\"fields\":[{\"name\":\"test\",\"id\":\"10\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10},\"value\":1234}],\"id\":\"test\"}"

      facet_json = Jason.decode!(raw_json)

      result = Facet.from_json(facet_json)

      assert {:ok,
              %Facet{
                children: ["child1", "child2"],
                eps: [],
                fields: [
                  %Field{
                    name: "test",
                    id: "10",
                    src: %Srcloc{
                      column: 5,
                      line: 1,
                      position: 50,
                      source: "test.rkt",
                      span: 10
                    },
                    value: 1234
                  }
                ],
                id: "test"
              }} == result
    end
  end

  describe "actor_env fromjson" do
    test "decode simple json" do
      json = [%{"actor_id" => "(0)", "detail" => %{"facets" => [], "dataflow" => []}}]
      result = ActorEnv.from_json(json)
      assert {:ok, %{"(0)" => fcts}} = result
      assert %ActorDetail{facets: %{}, dataflow: %{}} == fcts
    end

    test "decode json with facets" do
      json = [
        %{"actor_id" => "(0)", "detail" => %{"facets" => [], "dataflow" => []}},
        %{"actor_id" => "(1)", "detail" => %{"facets" => [], "dataflow" => []}},
        %{"actor_id" => "(3)", "detail" => %{"facets" => [], "dataflow" => []}},
        %{
          "actor_id" => "(4)",
          "detail" => %{
            "facets" => [
              %{
                "detail" => %{
                  "children" => [],
                  "endpoints" => [
                    %{
                      "description" => "(assert 67)",
                      "id" => "test",
                      "src" => %{
                        "column" => 0,
                        "line" => 56,
                        "position" => 1510,
                        "source" =>
                          "/Users/sam/git/syndicate-sandbox/syndicate-sandbox/tracing-facet-syntax.rkt",
                        "span" => 44
                      }
                    }
                  ],
                  "fields" => [],
                  "id" => "(5)"
                },
                "facet_id" => "(5)"
              }
            ],
            "dataflow" => []
          }
        }
      ]

      result = ActorEnv.from_json(json)

      assert {:ok,
              %{
                "(0)" => %ActorDetail{facets: %{}, dataflow: %{}},
                "(1)" => %ActorDetail{facets: %{}, dataflow: %{}},
                "(3)" => %ActorDetail{facets: %{}, dataflow: %{}},
                "(4)" => %ActorDetail{facets: fcts, dataflow: %{}}
              }} = result

      assert %{
               "(5)" => %Facet{
                 children: [],
                 eps: [
                   %Endpoint{
                     description: "(assert 67)",
                     id: "test",
                     src: %Srcloc{
                       column: 0,
                       line: 56,
                       position: 1510,
                       source:
                         "/Users/sam/git/syndicate-sandbox/syndicate-sandbox/tracing-facet-syntax.rkt",
                       span: 44
                     }
                   }
                 ],
                 fields: [],
                 id: "(5)"
               }
             } == fcts
    end
  end
end
