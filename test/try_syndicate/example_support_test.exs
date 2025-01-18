defmodule TrySyndicate.ExampleSupportTest do
  use ExUnit.Case, async: true

  alias TrySyndicate.ExampleSupport

  @examples_root Application.app_dir(:try_syndicate, "priv/examples")
  @flavor :classic
  @bank_account "bank-account.rkt"

  setup do
    File.mkdir_p!(@examples_root <> "/#{@flavor}")
    :ok
  end

  describe "available_examples/0" do
    test "returns a map of available examples for each flavor" do
      available = ExampleSupport.available_examples()
      assert Enum.member?(Map.get(available, @flavor), @bank_account)
    end
  end

  describe "available_examples/1" do
    test "returns a list of available examples for the given flavor" do
      assert Enum.member?(ExampleSupport.available_examples(@flavor), @bank_account)
    end

  end

  describe "fetch_example/2" do
    test "succeeds if it exists" do
      assert elem(ExampleSupport.fetch_example(@flavor, @bank_account), 0) == :ok
    end

    test "returns an error if the example file does not exist" do
      assert ExampleSupport.fetch_example(@flavor, "nonexistent.rkt") == {:error, "Failed to read example: :enoent"}
    end
  end

  describe "example_path/2" do
    test "returns the correct path for the given flavor and name" do
      assert ExampleSupport.example_path(@flavor, "example1.rkt") == @examples_root <> "/#{@flavor}/example1.rkt"
    end
  end

  describe "format_example/1" do
    test "removes the #lang line from the content" do
      content = "#lang racket\n(content)"
      assert ExampleSupport.format_example(content) == "(content)"
    end
  end

  describe "remove_hash_lang/1" do
    test "removes lines starting with #lang" do
      content = "#lang racket\n(content)"
      assert ExampleSupport.remove_hash_lang(content) == "(content)"
    end

    test "removes lines before the #lang" do
      content = "a\nb\nc\n#lang racket\n(content)"
      assert ExampleSupport.remove_hash_lang(content) == "(content)"
    end
  end

  describe "hash_lang?/1" do
    test "returns true if the line starts with #lang" do
      assert ExampleSupport.hash_lang?("#lang racket") == true
    end

    test "returns false if the line does not start with #lang" do
      assert ExampleSupport.hash_lang?("(content)") == false
    end
  end
end
