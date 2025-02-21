defmodule TrySyndicate.Syndicate.DataspaceTrace do
  @moduledoc """
  This module defines the data used to represent a trace of dataspace execution
  and related utilities.
  """

  alias TrySyndicate.Syndicate.{Dataspace, Actor, ActorEnv, TraceNotification}

  @type raw_trace() :: %{
          non_neg_integer() => Dataspace.t()
        }

  @type filter() :: %{
          names: [String.t()],
          pids: [Dataspace.actor_id()]
        }

  @type t() :: %{
          trace: raw_trace(),
          filter: filter(),
          filtered: %{non_neg_integer() => {Dataspace.t(), non_neg_integer()}},
          actors: %{non_neg_integer() => ActorEnv.t()}
        }

  @spec new() :: t()
  @spec new(filter()) :: t()
  def new(filter \\ %{names: [], pids: []}),
    do: %{trace: %{}, filter: filter, filtered: %{}, actors: %{}}

  @spec apply_filter(raw_trace(), filter()) :: t()
  def apply_filter(trace, filter) when map_size(trace) == 0,
    do: new(filter)

  def apply_filter(trace, filter) do
    base = %{0 => {filter_ds(trace[0], filter), 0}}

    filtered =
      Enum.reduce(1..(map_size(trace) - 1), base, fn time, filtered ->
        add_filtered_step(filtered, filter, time, trace[time])
      end)

    %{trace: trace, filter: filter, filtered: filtered, actors: %{}}
  end

  @spec apply_notification(t(), TraceNotification.t()) :: t()
  def apply_notification(state, notification) do
    case notification do
      %TraceNotification{type: :dataspace, detail: dataspace} ->
        add_step(state, dataspace)

      %TraceNotification{type: :actors, detail: actors} ->
        put_in(state, [:actors, max(0, map_size(state.trace) - 1)], actors)
    end
  end

  @spec add_step(t(), Dataspace.t()) :: t()
  def add_step(state, dataspace) do
    next_time = map_size(state.trace)

    put_in(state, [:trace, next_time], dataspace)
    |> put_in([:filtered], add_filtered_step(state.filtered, state.filter, next_time, dataspace))
  end

  @spec update_filter(t(), filter(), non_neg_integer()) :: {t(), non_neg_integer()}
  def update_filter(state, new_filter, prev_step) do
    filtered = apply_filter(state.trace, new_filter)
    prev_raw_idx = elem(state.filtered[prev_step], 1)

    last_filtered =
      Enum.filter(filtered.filtered, fn {idx, _} -> idx <= prev_raw_idx end)
      |> Enum.max_by(fn {idx, _} -> idx end)
      |> elem(0)

    {%{trace: state.trace, filter: new_filter, actors: state.actors, filtered: filtered.filtered},
     last_filtered}
  end

  def add_filtered_step(filtered, filter, time, dataspace) do
    next_filtered = filter_ds(dataspace, filter)
    filtered_len = map_size(filtered)
    last_filtered = filtered[filtered_len - 1]

    if last_filtered && mostly_equal?(elem(last_filtered, 0), next_filtered) do
      filtered
    else
      Map.put(filtered, filtered_len, {next_filtered, time})
    end
  end

  @spec filter_ds(Dataspace.t(), filter()) :: Dataspace.t()
  def filter_ds(dataspace, filter) do
    %Dataspace{
      dataspace
      | actors: filter_actors(dataspace.actors, filter),
        active_actor: filter_active(dataspace.active_actor, dataspace.actors, filter),
        pending_actions: filter_pending(dataspace.pending_actions, dataspace.actors, filter)
    }
  end

  def filter_actors(actors, filter) do
    for {actor_id, actor} <- actors, !filtered?(actor_id, actor, filter), into: %{} do
      {actor_id, actor}
    end
  end

  @spec filtered?(Dataspace.actor_id(), Actor.t() | nil, filter()) :: boolean()
  def filtered?(actor_id, actor, filter) do
    actor_id in filter.pids or (actor && actor.name in filter.names)
  end

  def filter_active(:none, _actors, _filter), do: :none

  def filter_active({actor_id, event, actions}, actors, filter) do
    if filtered?(actor_id, actors[actor_id], filter) do
      :none
    else
      {actor_id, event, actions}
    end
  end

  def filter_pending(pending_actions, actors, filter) do
    for {time, actions} <- pending_actions,
        !filtered?(time.space, actors[time.space], filter),
        into: [] do
      {time, actions}
    end
  end

  def mostly_equal?(ds1, ds2) do
    ds1.actors == ds2.actors and ds1.active_actor == ds2.active_actor and
      MapSet.new(ds1.pending_actions) == MapSet.new(ds2.pending_actions)
  end
end
