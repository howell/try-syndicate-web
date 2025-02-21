defmodule TrySyndicate.Syndicate.Srcloc do
  @fields [:source, :line, :column, :position, :span]

  @type t() :: %__MODULE__{
          source: any(),
          line: false | non_neg_integer(),
          column: false | non_neg_integer(),
          position: false | non_neg_integer(),
          span: false | non_neg_integer(),
        }

  @enforce_keys @fields
  defstruct @fields
end
