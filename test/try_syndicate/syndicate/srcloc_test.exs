defmodule TrySyndicate.Syndicate.SrclocTest do
  use ExUnit.Case, async: true
  alias TrySyndicate.Syndicate.Srcloc

  describe "select/2" do
    test "extracts code from a single line" do
      code = "function hello() { return 'world'; }"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 9, span: 5, position: 10})
      assert result == "hello"
    end

    test "extracts code from the beginning of a line" do
      code = "function hello() { return 'world'; }"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 0, span: 8, position: 1})
      assert result == "function"
    end

    test "extracts code spanning multiple lines" do
      code = """
      function hello() {
        return 'world';
      }
      """
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 9, span: 18, position: 1})
      assert result == "hello() {\n  return"
    end

    test "extracts code starting from a later line" do
      code = """
      // This is a comment
      function hello() {
        return 'world';
      }
      """
      result = Srcloc.select(code, %Srcloc{source: "test", line: 2, column: 0, span: 8, position: 1})
      assert result == "function"
    end

    test "handles empty input" do
      code = ""
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 0, span: 5, position: 1})
      assert result == ""
    end

    test "handles span beyond the end of the text" do
      code = "short"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 0, span: 10, position: 1})
      assert result == "short"
    end

    test "handles line beyond the number of lines" do
      code = "single line"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 5, column: 0, span: 5, position: 1})
      assert result == ""
    end

    test "handles column beyond the line length" do
      code = "short"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 9, span: 5, position: 1})
      assert result == ""
    end

    test "handles multi-byte Unicode characters" do
      code = "function 你好() { return '世界'; }"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 9, span: 2, position: 1})
      assert result == "你好"
    end

    test "extracts code from the last line" do
      code = """
      line 1
      line 2
      line 3
      """
      result = Srcloc.select(code, %Srcloc{source: "test", line: 3, column: 0, span: 6, position: 1})
      assert result == "line 3"
    end

    test "handles Windows-style line endings (CRLF)" do
      code = "line 1\r\nline 2\r\nline 3"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 2, column: 0, span: 6, position: 1})
      assert result == "line 2"
    end

    test "handles zero span" do
      code = "function hello() { return 'world'; }"
      result = Srcloc.select(code, %Srcloc{source: "test", line: 1, column: 9, span: 0, position: 1})
      assert result == ""
    end
  end

  describe "trim_leading_whitespace/2" do
    test "removes exactly max_length whitespace characters" do
      assert Srcloc.trim_leading_whitespace("    hello", 2) == "  hello"
    end

    test "removes all whitespace if less than max_length" do
      assert Srcloc.trim_leading_whitespace("  hello", 4) == "hello"
    end

    test "removes no more than max_length characters" do
      assert Srcloc.trim_leading_whitespace("      hello", 4) == "  hello"
    end

    test "handles zero max_length" do
      assert Srcloc.trim_leading_whitespace("  hello", 0) == "  hello"
    end

    test "handles string with no leading whitespace" do
      assert Srcloc.trim_leading_whitespace("hello", 3) == "hello"
    end

    test "handles empty string" do
      assert Srcloc.trim_leading_whitespace("", 5) == ""
    end

    test "handles string with only whitespace" do
      assert Srcloc.trim_leading_whitespace("   ", 2) == " "
      assert Srcloc.trim_leading_whitespace("   ", 3) == ""
      assert Srcloc.trim_leading_whitespace("   ", 5) == ""
    end

    test "handles different types of whitespace" do
      assert Srcloc.trim_leading_whitespace("\t\n  hello", 3) == " hello"
    end

    test "handles multiline strings" do
      input = """
          first line
        second line
      """
      expected = """
        first line
      second line
      """
      assert Srcloc.trim_leading_whitespace(input, 2) == expected
    end

    test "only trims from the beginning of the string" do
      assert Srcloc.trim_leading_whitespace("hello  world  ", 4) == "hello  world  "
    end
  end

  describe "resolve/2" do
    test "extracts code from a simple source location" do
      code = "function hello() { return 'world'; }"
      srcloc = %Srcloc{source: "0", line: 1, column: 0, span: 8, position: 0}

      assert Srcloc.resolve(code, srcloc) == "function"
    end

    test "extracts code with proper indentation preserved" do
      code = """
      function example() {
        const x = 10;
        if (x > 5) {
          return true;
        }
        return false;
      }
      """

      srcloc = %Srcloc{source: "0", line: 3, column: 2, span: 30, position: 1}

      assert Srcloc.resolve(code, srcloc) =="""
      if (x > 5) {
        return true;
      """
    end

    test "handles multiline extraction" do
      code = """
      function example() {
        const x = 10;
        if (x > 5) {
          return true;
        }
        return false;
      }
      """

      srcloc = %Srcloc{source: "0", line: 3, column: 2, span: 35, position: 1}

      expected = """
      if (x > 5) {
        return true;
      }
      """

      assert Srcloc.resolve(code, srcloc) == expected
    end

    test "trims leading whitespace based on column" do
      code = """
          const x = 10;
          const y = 20;
      """

      srcloc = %Srcloc{source: "0", line: 1, column: 4, span: 13, position: 1}

      assert Srcloc.resolve(code, srcloc) == "const x = 10;"
    end

    test "handles indentation in multiline extraction" do
      code = """
      function example() {
          if (condition) {
              doSomething();
              doSomethingElse();
          }
      }
      """

      srcloc = %Srcloc{source: "0", line: 2, column: 4, span: 73, position: 1}

      expected = """
      if (condition) {
          doSomething();
          doSomethingElse();
      }
      """

      assert Srcloc.resolve(code, srcloc) == expected
    end

    test "handles extraction at the end of the file" do
      code = "const x = 10;"
      srcloc = %Srcloc{source: "0", line: 1, column: 6, span: 10, position: 1}

      assert Srcloc.resolve(code, srcloc) == "x = 10;"
    end

    test "handles empty source" do
      code = ""
      srcloc = %Srcloc{source: "0", line: 1, column: 1, span: 5, position: 1}

      assert Srcloc.resolve(code, srcloc) == ""
    end

    test "handles source location beyond the content" do
      code = "short"
      srcloc = %Srcloc{source: "0", line: 2, column: 1, span: 5, position: 1}

      assert Srcloc.resolve(code, srcloc) == ""
    end

    test "handles zero span" do
      code = "function hello() { return 'world'; }"
      srcloc = %Srcloc{source: "0", line: 1, column: 10, span: 0, position: 1}

      assert Srcloc.resolve(code, srcloc) == ""
    end

    test "handles tabs in indentation" do
      code = "\t\tconst x = 10;"
      srcloc = %Srcloc{source: "0", line: 1, column: 2, span: 13, position: 1}

      assert Srcloc.resolve(code, srcloc) == "const x = 10;"
    end
  end
end
