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
end
