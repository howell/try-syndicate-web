defmodule TrySyndicate.Syndicate.SpaceTime do
  @type t() :: %__MODULE__{
          space: any(),
          time: non_neg_integer()
        }
  defstruct [
    :space,
    :time
  ]

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) and json["space"] && json["time"] do
      space = json["space"]
      time = json["time"]
      if is_integer(time) do
        {:ok, %__MODULE__{space: space, time: time}}
      else
        {:error, "Invalid time value"}
      end
    else
      {:error, "Expected a map with keys 'space' and 'time'"}
    end
  end
end
