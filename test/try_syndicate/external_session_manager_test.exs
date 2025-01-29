defmodule TrySyndicate.ExternalSessionManagerTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.ExternalSessionManager.OutputStatus

  describe "OutputStatus.collect_ready/2" do
    test "collect_ready returns empty when pending is empty" do
      pending = []
      last_seq = 1
      {collected, leftover, new_last} = OutputStatus.collect_ready(pending, last_seq)
      assert collected == []
      assert leftover == []
      assert new_last == 1
    end

    test "collects consecutive sequences" do
      pending = [{2, "bar"}, {3, "baz"}]
      next_seq = 2
      {collected, leftover, new_next} = OutputStatus.collect_ready(pending, next_seq)
      assert collected == ["bar", "baz"]
      assert leftover == []
      assert new_next == 4
    end

    test "collect_ready handles unsorted pending items" do
      pending = [{3, "baz"}, {2, "bar"}, {6, "qux"}, {4, "quux"}]
      next_seq = 2
      {collected, leftover, new_next} = OutputStatus.collect_ready(pending, next_seq)
      assert collected == ["bar", "baz", "quux"]
      assert leftover == [{6, "qux"}]
      assert new_next == 5
    end

    test "stops collecting on missing sequence" do
      pending = [{3, "baz"}, {5, "qux"}]
      next_seq = 3
      {collected, leftover, new_next} = OutputStatus.collect_ready(pending, next_seq)
      assert collected == ["baz"]
      assert leftover == [{5, "qux"}]
      assert new_next == 4
    end

    test "collect_ready returns empty when no sequence equals last_seq + 1" do
      pending = [{4, "quux"}, {5, "corge"}]
      last_seq = 1
      {collected, leftover, new_last} = OutputStatus.collect_ready(pending, last_seq)
      assert collected == []
      assert leftover == pending
      assert new_last == 1
    end
  end

  describe "OutputStatus.handle_session_output/3" do
    test "initial sequence number and seq_no matches next_expected_seq" do
      initial_status = OutputStatus.new(0)

      {data_list, new_status} =
        OutputStatus.handle_session_output(initial_status, 0, "hello")

      assert data_list == ["hello"]
      assert new_status.next_expected_seq == 1
      assert new_status.pending == []
    end

    test "seq_no is not the next expected sequence number (less than expected)" do
      initial_status = OutputStatus.new(2)

      {data_list, new_status} =
        OutputStatus.handle_session_output(initial_status, 1, "duplicate")

      assert data_list == []
      assert new_status.next_expected_seq == 2
      assert new_status.pending == []
    end

    test "seq_no is not the next expected sequence number (greater than expected)" do
      initial_status = OutputStatus.new(1)

      {data_list, new_status} =
        OutputStatus.handle_session_output(initial_status, 3, "future data")

      assert data_list == []
      assert new_status.next_expected_seq == 1
      assert new_status.pending == [{3, "future data"}]
    end

    test "seq_no == next_expected_seq and pending can be collected" do
      initial_status = OutputStatus.new(2)
      pending = [{3, "baz"}, {4, "qux"}]
      updated_status = %OutputStatus{initial_status | pending: pending}

      {data_list, new_status} =
        OutputStatus.handle_session_output(updated_status, 2, "bar")

      assert data_list == ["bar", "baz", "qux"]
      assert new_status.next_expected_seq == 5
      assert new_status.pending == []
    end

    test "seq_no == next_expected_seq and some pending can be collected" do
      initial_status = OutputStatus.new(2)
      pending = [{4, "qux"}, {5, "quux"}]
      updated_status = %OutputStatus{initial_status | pending: pending}

      {data_list, new_status} =
        OutputStatus.handle_session_output(updated_status, 2, "bar")

      assert data_list == ["bar"]
      assert new_status.next_expected_seq == 3
      assert new_status.pending == [{4, "qux"}, {5, "quux"}]
    end

    test "collect_ready collects multiple consecutive pending messages" do
      initial_status = OutputStatus.new(1)
      pending = [{2, "foo"}, {3, "bar"}, {5, "baz"}]
      updated_status = %OutputStatus{initial_status | pending: pending}

      {data_list, new_status} =
        OutputStatus.handle_session_output(updated_status, 1, "start")

      assert data_list == ["start", "foo", "bar"]
      assert new_status.next_expected_seq == 4
      assert new_status.pending == [{5, "baz"}]
    end

    test "seq_no > next_expected_seq and pending is empty" do
      old_status = OutputStatus.new(1)
      seq_no = 3
      data = "future data"

      {data_list, new_status} =
        OutputStatus.handle_session_output(old_status, seq_no, data)

      assert data_list == []
      assert new_status.next_expected_seq == 1
      assert new_status.pending == [{3, "future data"}]
    end

    test "seq_no > next_expected_seq and pending has existing items" do
      old_status = %OutputStatus{next_expected_seq: 2, pending: [{5, "qux"}, {4, "quux"}]}
      seq_no = 6
      data = "more future data"

      {data_list, new_status} =
        OutputStatus.handle_session_output(old_status, seq_no, data)

      assert data_list == []
      assert new_status.next_expected_seq == 2
      assert new_status.pending == [{6, "more future data"}, {5, "qux"}, {4, "quux"}]
    end
  end
end
