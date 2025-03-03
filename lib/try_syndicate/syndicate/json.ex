defmodule TrySyndicate.Syndicate.Json do
  @type parser() :: (term() -> {:ok, term()} | {:error, String.t()})

  @spec parse_field(term(), String.t()) :: {:ok, any()} | {:error, String.t()}
  @spec parse_field(term(), String.t(), parser()) :: {:ok, any()} | {:error, String.t()}
  def parse_field(json, field, validator \\ &success/1)

  def parse_field(json, field, validator) when is_map(json) do
    case Map.get(json, field) do
      nil ->
        {:error, "Missing field: #{field}"}

      value ->
        case validator.(value) do
          {:ok, value} -> {:ok, value}
          {:error, reason} -> {:error, "Invalid value for #{field}: #{reason}"}
        end
    end
  end

  def parse_field(_json, field, _validator), do: {:error, "Invalid JSON for field #{field}: parent is not a map"}

  def parse_list(json, parser \\ &success/1)
  def parse_list(json, parser) when is_list(json) do
    Enum.reduce_while(json, {:ok, []}, fn item_json, {:ok, acc} ->
      case parser.(item_json) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> (fn
          {:ok, items} -> {:ok, Enum.reverse(items)}
          error -> error
        end).()
  end

  def parse_list(_json, _parser), do: {:error, "Invalid JSON: not a list"}

  def parse_optional(json, parser) do
    if json do
      parser.(json)
    else
      {:ok, json}
    end
  end

  defp success(value), do: {:ok, value}
end
