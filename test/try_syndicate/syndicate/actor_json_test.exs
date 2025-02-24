defmodule TrySyndicate.Syndicate.ActorJsonTest do
  use ExUnit.Case, async: true

  alias Jason
  alias TrySyndicate.Syndicate.{ActorEnv, Facet, Field, Endpoint, Srcloc}

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
        "{\"description\":\"'(assert 'hello)\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10}}"

      endpoint_json = Jason.decode!(raw_json)

      result = Endpoint.from_json(endpoint_json)

      assert {:ok,
              %Endpoint{
                description: "'(assert 'hello)",
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
        "{\"name\":\"test\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10},\"value\":1234}"

      field_json = Jason.decode!(raw_json)

      result = Field.from_json(field_json)

      assert {:ok,
              %Field{
                name: "test",
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
        "{\"children\":[\"child1\",\"child2\"],\"endpoints\":[],\"fields\":[{\"name\":\"test\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10},\"value\":1234}],\"id\":\"test\"}"

      facet_json = Jason.decode!(raw_json)

      result = Facet.from_json(facet_json)

      assert {:ok,
              %Facet{
                children: ["child1", "child2"],
                eps: [],
                fields: [
                  %Field{
                    name: "test",
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
      json = [%{"actor_id" => "(0)", "facets" => []}]
      result = ActorEnv.from_json(json)
      assert {:ok, %{"(0)" => fcts}} = result
      assert %{} == fcts
    end

    test "decode json with facets" do
      json = [
        %{"actor_id" => "(0)", "facets" => []},
        %{"actor_id" => "(1)", "facets" => []},
        %{"actor_id" => "(3)", "facets" => []},
        %{
          "actor_id" => "(4)",
          "facets" => [
            %{
              "detail" => %{
                "children" => [],
                "endpoints" => [
                  %{
                    "description" => "(assert 67)",
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
          ]
        }
      ]

      result = ActorEnv.from_json(json)
      assert {:ok, %{"(0)" => %{}, "(1)" => %{}, "(3)" => %{}, "(4)" => fcts}} = result

      assert %{
               "(5)" => %Facet{
                 children: [],
                 eps: [
                   %Endpoint{
                     description: "(assert 67)",
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
