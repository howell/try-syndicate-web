defmodule TrySyndicate.Syndicate.Srcloc do
  alias TrySyndicate.Syndicate.Json
  @fields [:source, :line, :column, :position, :span]

  @type t() :: %__MODULE__{
          source: any(),
          line: false | non_neg_integer(),
          column: false | non_neg_integer(),
          position: false | non_neg_integer(),
          span: false | non_neg_integer()
        }

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      with {:ok, source} <- Json.parse_field(json, "source"),
           {:ok, line} <- Json.parse_field(json, "line"),
           {:ok, column} <- Json.parse_field(json, "column"),
           {:ok, position} <- Json.parse_field(json, "position"),
           {:ok, span} <- Json.parse_field(json, "span") do
        {:ok,
         %__MODULE__{
           source: source,
           line: line,
           column: column,
           position: position,
           span: span
         }}
      else
        {:error, reason} -> {:error, "Invalid srcloc JSON: #{reason}"}
      end
    else
      {:error, "Invalid srcloc JSON: not a map"}
    end
  end

  @spec resolve(String.t(), t()) :: String.t()
  @doc """
  Extract the code from the submission at the given line and column.
  """
  def resolve(submission, %__MODULE__{line: line, column: column, span: span}) do
    lines = String.split(submission, "\n")

    lines
    |> Enum.drop(line - 1)
    |> Enum.join("\n")
    |> String.slice(column - 1, span)
  end
end
