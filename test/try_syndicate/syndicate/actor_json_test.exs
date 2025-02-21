defmodule TrySyndicate.Syndicate.ActorJsonTest do
  use ExUnit.Case, async: true

  alias Jason
  alias TrySyndicate.Syndicate.{Actor, ActorEnv, Dataspace, Facet, Field, Endpoint, Srcloc}

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
      raw_json = "{\"description\":\"'(assert 'hello)\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10}}"
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
      raw_json = "{\"name\":\"test\",\"src\":{\"column\":5,\"line\":1,\"position\":50,\"source\":\"test.rkt\",\"span\":10},\"value\":1234}"
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
end
