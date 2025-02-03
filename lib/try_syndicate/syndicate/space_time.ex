defmodule TrySyndicate.Syndicate.SpaceTime do
  @type t() :: %__MODULE__{
          space: any(),
          time: non_neg_integer()
        }
  defstruct [
    :space,
    :time
  ]
end
