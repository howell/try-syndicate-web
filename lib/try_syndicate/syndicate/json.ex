defmodule TrySyndicate.Syndicate.Json do
  @spec parse_field(map(), String.t(), (any() -> bool())) :: {:ok, any()} | {:error, String.t()}
  def parse_field(json, field, validator \\ fn _ -> true end) do
    case Map.get(json, field) do
      nil ->
        {:error, "Missing field: #{field}"}

      value ->
        if validator.(value) do
          {:ok, value}
        else
          {:error, "Invalid field: #{field}"}
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
