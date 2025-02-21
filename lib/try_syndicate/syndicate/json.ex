defmodule TrySyndicate.Syndicate.Json do
  @type parser() :: (term() -> {:ok, term()} | {:error, String.t()})

  @spec parse_field(map(), String.t()) :: {:ok, any()} | {:error, String.t()}
  @spec parse_field(map(), String.t(), parser()) :: {:ok, any()} | {:error, String.t()}
  def parse_field(json, field, validator \\ fn v -> {:ok, v} end) do
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

  def parse_list(json, parser) do
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

  def parse_optional(json, parser) do
    if json do
      parser.(json)
    else
      {:ok, json}
    end
  end
end
