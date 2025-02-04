defmodule TrySyndicate.Syndicate.SpaceTime do
  @type t() :: %__MODULE__{
          space: any(),
          time: non_neg_integer()
        }
  defstruct [
    :space,
    :time
  ]

  @spec from_json(term()) :: t() | nil
  def from_json(json) do
    if is_map(json) && json["space"] && json["time"] do
      space = json["space"]
      time = json["time"]
      if is_integer(time), do: %__MODULE__{space: space, time: time}, else: nil
    else
      nil
    end
  end
end
