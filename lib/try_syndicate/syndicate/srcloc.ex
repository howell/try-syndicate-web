defmodule TrySyndicate.Syndicate.Srcloc do
  @fields [:source, :line, :column, :position, :span]

  @type t() :: %__MODULE__{
          source: any(),
          line: false | non_neg_integer(),
          column: false | non_neg_integer(),
          position: false | non_neg_integer(),
          span: false | non_neg_integer(),
        }

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      with {:ok, source} <- parse_src_field(json, "source"),
           {:ok, line} <- parse_src_field(json, "line"),
           {:ok, column} <- parse_src_field(json, "column"),
           {:ok, position} <- parse_src_field(json, "position"),
           {:ok, span} <- parse_src_field(json, "span") do
        {:ok,
         %__MODULE__{
           source: source,
           line: line,
           column: column,
           position: position,
           span: span
         }}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Invalid srcloc JSON: not a map"}
    end
  end

  defp parse_src_field(json, field) do
    if Map.has_key?(json, field) do
      {:ok, json[field]}
    else
      {:error, "Invalid srcloc JSON: missing required field '#{field}'"}
    end
  end
end
