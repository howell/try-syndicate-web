defmodule TrySyndicate.Syndicate.ActorJsonTest do
  use ExUnit.Case, async: true

  alias Jason
  alias TrySyndicate.Syndicate.{Actor, ActorEnv, Dataspace, Facet, Field, Srcloc}

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
end
