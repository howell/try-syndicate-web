defmodule Syndicate.ActorStepRegressionTest do
  use ExUnit.Case

  alias TrySyndicate.Syndicate.DataspaceTrace

  setup do
    {trace, _} = Code.eval_file("actor_step_regression_trace.txt", __DIR__)
    {:ok, trace: trace}
  end

  test "actor step regression", %{trace: trace} do
    banker_pid = "(4)"
    assert DataspaceTrace.actor_trace(trace, banker_pid) == [40, 45, 67, 70]
    assert DataspaceTrace.actor_step_count(trace, banker_pid) == 4
    assert DataspaceTrace.first_actor_step(trace, banker_pid) == 1 # filtered step corresponding to raw step 40
    assert DataspaceTrace.next_actor_step(trace, banker_pid, 1) == 4 # filtered step corresponding to raw step 45
    assert DataspaceTrace.prev_actor_step(trace, banker_pid, 4) == 1
    assert DataspaceTrace.next_actor_step(trace, banker_pid, 4) == 20
    assert DataspaceTrace.prev_actor_step(trace, banker_pid, 20) == 4
    assert DataspaceTrace.next_actor_step(trace, banker_pid, 20) == 23
    assert DataspaceTrace.prev_actor_step(trace, banker_pid, 23) == 20
    assert DataspaceTrace.last_actor_step(trace, banker_pid) == 23
  end
end
