defmodule TrySyndicate.Syndicate.Field do
  alias TrySyndicate.Syndicate.{Json, Srcloc}
  @fields [:name, :value, :src]

  @type t() :: %__MODULE__{
          name: String.t(),
          value: String.t(),
          src: Srcloc.t(),
        }

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      with {:ok, name} <- Json.parse_field(json, "name"),
           {:ok, value} <- Json.parse_field(json, "value"),
           {:ok, src} <- Srcloc.from_json(json["src"]) do
        {:ok,
         %__MODULE__{
           name: name,
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
