defmodule TrySyndicate.Syndicate.SrclocTest do
  use ExUnit.Case, async: true
  alias TrySyndicate.Syndicate.Srcloc

  describe "extract_code/4" do
    test "extracts code from a single line" do
      code = "function hello() { return 'world'; }"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 9, span: 5, position: 10})
      assert result == "hello"
    end

    test "extracts code from the beginning of a line" do
      code = "function hello() { return 'world'; }"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 0, span: 8, position: 1})
      assert result == "function"
    end

    test "extracts code spanning multiple lines" do
      code = """
      function hello() {
        return 'world';
      }
      """
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 9, span: 18, position: 1})
      assert result == "hello() {\n  return"
    end

    test "extracts code starting from a later line" do
      code = """
      // This is a comment
      function hello() {
        return 'world';
      }
      """
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 2, column: 0, span: 8, position: 1})
      assert result == "function"
    end

    test "handles empty input" do
      code = ""
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 0, span: 5, position: 1})
      assert result == ""
    end

    test "handles span beyond the end of the text" do
      code = "short"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 0, span: 10, position: 1})
      assert result == "short"
    end

    test "handles line beyond the number of lines" do
      code = "single line"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 5, column: 0, span: 5, position: 1})
      assert result == ""
    end

    test "handles column beyond the line length" do
      code = "short"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 9, span: 5, position: 1})
      assert result == ""
    end

    test "handles multi-byte Unicode characters" do
      code = "function 你好() { return '世界'; }"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 9, span: 2, position: 1})
      assert result == "你好"
    end

    test "extracts code from the last line" do
      code = """
      line 1
      line 2
      line 3
      """
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 3, column: 0, span: 6, position: 1})
      assert result == "line 3"
    end

    test "handles Windows-style line endings (CRLF)" do
      code = "line 1\r\nline 2\r\nline 3"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 2, column: 0, span: 6, position: 1})
      assert result == "line 2"
    end

    test "handles zero span" do
      code = "function hello() { return 'world'; }"
      result = Srcloc.resolve(code, %Srcloc{source: "test", line: 1, column: 9, span: 0, position: 1})
      assert result == ""
    end
  end
end
