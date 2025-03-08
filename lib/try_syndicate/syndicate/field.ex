defmodule TrySyndicate.Syndicate.Field do
  alias TrySyndicate.Syndicate.{Json, Srcloc, Core}
  @fields [:name, :id, :value, :src]

  @type t() :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          value: String.t(),
          src: Srcloc.t(),
        }

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      with {:ok, name} <- Json.parse_field(json, "name"),
           {:ok, value} <- Json.parse_field(json, "value", &Core.json_to_formatted_value/1),
           {:ok, src} <- Srcloc.from_json(json["src"]),
           {:ok, id} <- Json.parse_field(json, "id") do
        {:ok,
         %__MODULE__{
           name: name,
           id: id,
           value: value,
           src: src
         }}
      else
        {:error, reason} -> {:error, "Invalid field JSON: #{reason}"}
      end
    else
      {:error, "Invalid field JSON: not a map"}
    end
  end
end
