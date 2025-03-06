defmodule TrySyndicate.Syndicate.Endpoint do
  alias TrySyndicate.Syndicate.{Srcloc, Json}
  @fields [:description, :src, :id]

  @type t() :: %__MODULE__{
          description: String.t(),
          id: String.t(),
          src: Srcloc.t()
        }

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      with {:ok, description} <- Json.parse_field(json, "description"),
           {:ok, src} <- Srcloc.from_json(json["src"]),
           {:ok, id} <- Json.parse_field(json, "id") do
        {:ok,
         %__MODULE__{
           description: description,
           id: id,
           src: src
         }}
      else
        {:error, reason} -> {:error, "Invalid endpoint JSON: #{reason}"}
      end
    else
      {:error, "Invalid endpoint JSON: not a map"}
    end
  end
end
