defmodule TrySyndicate.Syndicate.Endpoint do
  @fields [:description, :src]

  @type t() :: %__MODULE__{
          description: String.t(),
          src: TrySyndicate.Syndicate.Srcloc.t(),
        }

  @enforce_keys @fields
  defstruct @fields
end
