defmodule TrySyndicate.Syndicate.Facet do
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

end
