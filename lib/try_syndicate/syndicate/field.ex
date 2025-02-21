defmodule TrySyndicate.Syndicate.Field do
  @fields [:name, :value, :src]

  @type t() :: %__MODULE__{
          name: String.t(),
          value: any(),
          src: TrySyndicate.Syndicate.Srcloc.t(),
        }

  @enforce_keys @fields
  defstruct @fields
end
