defmodule TrySyndicate.Syndicate.Dataspace do
  @moduledoc """
  This module defines the data used to represent a dataspace.
  """
  alias TrySyndicate.Syndicate.{Actor, SpaceTime, Core}

  @type t() :: %__MODULE__{
          actors: %{any() => Actor.t()},
          active_actor: :none | {Actor.t(), any()},
          recent_messages: [String.t()],
          pending_acts: [{SpaceTime.t(), [Core.action()]}]
        }

  defstruct [
    :actors,
    :active_actor,
    :recent_messages,
    :pending_acts
  ]
end
