defmodule TrySyndicate.ExampleSupport do

  @type flavor :: :classic
  @flavors [:classic]

  @spec available_examples() :: %{flavor => [String.t()]}
  def available_examples() do
    for flavor <- @flavors, into: %{} do
      {flavor, available_examples(flavor)}
    end
  end

  @spec available_examples(flavor) :: [String.t()]
  def available_examples(flavor) do
    case File.ls(example_path(flavor, "")) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".rkt"))
      _ -> []
    end
  end

  def fetch_example(flavor, name) do
    case File.read(example_path(flavor, name)) do
      {:ok, content} -> {:ok, format_example(content)}
      {:error, reason} -> {:error, "Failed to read example: #{inspect(reason)}"}
    end
  end

  @spec example_path(flavor, String.t()) :: String.t()
  def example_path(flavor, name) do
    Application.app_dir(:try_syndicate, "priv/examples/#{flavor}/#{name}")
  end

  @spec format_example(String.t()) :: String.t()
  def format_example(content) do
    remove_hash_lang(content)
  end

  @spec remove_hash_lang(String.t()) :: String.t()
  def remove_hash_lang(content) do
    content
    |> String.split("\n")
    |> Enum.drop_while(&!hash_lang?(&1))
    |> Enum.drop_while(&String.starts_with?(&1, "#lang"))
    |> Enum.drop_while(&String.trim(&1) == "")
    |> Enum.join("\n")
  end

  @spec hash_lang?(String.t()) :: boolean()
  def hash_lang?(line) do
    String.starts_with?(line, "#lang")
  end
end
