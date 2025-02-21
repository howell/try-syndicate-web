defmodule TrySyndicate.Syndicate.Facet do
  alias TrySyndicate.Syndicate.{Field, Endpoint, Json}
  @fields [:id, :fields, :eps, :children]

  @type fid() :: String.t()

  @type t() :: %__MODULE__{
          id: fid(),
          fields: list(TrySyndicate.Syndicate.Field.t()),
          eps: list(TrySyndicate.Syndicate.Endpoint.t()),
          children: list(fid()),
        }

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      with {:ok, id} <- Json.parse_field(json, "id"),
           {:ok, fields} <- Json.parse_field(json, "fields", fn json -> Json.parse_list(json, &Field.from_json/1) end),
           {:ok, eps} <- Json.parse_field(json, "eps", fn json -> Json.parse_list(json, &Endpoint.from_json/1) end),
           {:ok, children} <- Json.parse_field(json, "children", fn json -> Json.parse_list(json) end) do
        {:ok,
         %__MODULE__{
           id: id,
           fields: fields,
           eps: eps,
           children: children
         }}
      else
        {:error, reason} -> {:error, "Invalid facet JSON: #{reason}"}
      end
    else
      {:error, "Invalid facet JSON: not a map"}
    end
  end

end
