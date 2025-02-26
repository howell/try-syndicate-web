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

  @typedoc """
  A trace of states in the execution of a dataspace. Keys:
    - `trace`: a map of time steps  to dataspace states. The keys in the map are contiguous integers starting at 0.
    - `filter`: a map of names and pids to exclude from the trace.
    - `filtered`: a map of time steps to a dataspace state and the index of that state in the raw trace.
       The keys in the map are contiguous integers starting at 0.
    - `actors`: a map of time steps (indices of the raw trace) to the actor states at that step.
       The keys in the map are only the step indices where the actor states have changed.
  """
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

  @spec actors_at_step(t(), non_neg_integer()) :: ActorEnv.t()
  @doc """
  Returns the actor states at the specified step (index of the filtered trace).
  """
  def actors_at_step(state, step) do
    {_, raw_step} = state.filtered[step]

    case most_recent_at(state.actors, raw_step) do
      {_, actors} -> actors
      _ -> %{}
    end
  end

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

    {last_filtered, _} = most_recent_at(filtered.filtered, prev_raw_idx)

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

  @spec most_recent_at(Enumerable.t({non_neg_integer(), any()}), non_neg_integer()) ::
          {non_neg_integer(), any()} | nil
  def most_recent_at(elems, time) do
    Enum.filter(elems, fn {t, _} -> t <= time end)
    |> Enum.max_by(fn {idx, _} -> idx end, fn -> nil end)
  end

  @spec earliest_after(Enumerable.t({non_neg_integer(), any()}), non_neg_integer()) ::
          {non_neg_integer(), any()} | nil
  def earliest_after(elems, time) do
    Enum.filter(elems, fn {t, _} -> t >= time end)
    |> Enum.min_by(fn {idx, _} -> idx end, fn -> nil end)
  end

  @spec all_actors(t()) :: [{Dataspace.actor_id(), false | String.t()}]
  def all_actors(state) do
    all_actors_by(state.trace, &Function.identity/1)
  end

  @spec all_unfiltered_actors(t()) :: [{Dataspace.actor_id(), false | String.t()}]
  def all_unfiltered_actors(state) do
    all_actors_by(state.filtered, &elem(&1, 0))
  end

  defp all_actors_by(trace, selector) do
    trace
    |> Map.values()
    |> Enum.flat_map(&selector.(&1).actors)
    |> Enum.map(fn {id, actor} -> {id, actor.name} end)
    |> Enum.uniq()
  end

  @spec actor_at(t(), non_neg_integer(), Dataspace.actor_id()) :: ActorEnv.actor_detail() | nil
  def actor_at(trace, step, pid) do
    actors_at_step(trace, step)
    |> Map.get(pid)
  end

  @spec actor_present?(t(), non_neg_integer(), Dataspace.actor_id()) :: boolean()
  @doc """
  Returns true if the specified actor exists at the specified step (index of the filtered trace).
  """
  def actor_present?(trace, step, pid) do
    actors_at_step(trace, step)
    |> Map.has_key?(pid)
  end

  @spec actor_trace(t(), Dataspace.actor_id()) :: [non_neg_integer()]
  @doc """
  Returns a sequence of steps (indices of the raw trace) where the specified actor
  exists with a distinct state.
  For each distinct state, only the first occurrence is included.
  Steps are returned in ascending order.
  """
  def actor_trace(trace, pid) do
    trace.actors
    |> Enum.filter(fn {_t, env} -> Map.has_key?(env, pid) end)
    |> Enum.uniq_by(fn {_t, env} -> env[pid] end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @spec first_actor_step(t(), Dataspace.actor_id()) :: non_neg_integer() | nil
  @doc """
  Returns the first step (index of the filtered trace) where the specified actor
  exists with a distinct state.
  """
  def first_actor_step(trace, pid) do
    actor_trace(trace, pid)
    |> Enum.at(0)
    |> filtered_step_to(trace)
  end

  @spec last_actor_step(t(), Dataspace.actor_id()) :: non_neg_integer() | nil
  @doc """
  Returns the last step (index of the filtered trace) where the specified actor
  exists with a distinct state.
  """
  def last_actor_step(trace, pid) do
    actor_trace(trace, pid)
    |> Enum.at(-1)
    |> filtered_step_to(trace)
  end

  @spec next_actor_step(t(), Dataspace.actor_id(), non_neg_integer()) :: non_neg_integer() | nil
  @doc """
  Returns the next step (index of the filtered trace) where the specified actor
  exists with a distinct state.
  Returns nil if the specified step is the last step for the actor.
  Arguments:
    - `trace`: the trace to search
    - `pid`: the selected actor
    - `step`: the current step (index of the filtered trace)
  """
  def next_actor_step(trace, pid, step) do
    raw_step = elem(trace.filtered[step], 1)

    actor_trace(trace, pid)
    |> Enum.filter(fn t -> t > raw_step end)
    |> Enum.at(0)
    |> filtered_step_to(trace)
  end

  @spec prev_actor_step(t(), Dataspace.actor_id(), non_neg_integer()) :: non_neg_integer() | nil
  @doc """
  Returns the previous step (index of the filtered trace) where the specified actor
  exists with a distinct state.
  Returns nil if the specified step is the first step for the actor.
  Arguments:
    - `trace`: the trace to search
    - `pid`: the selected actor
    - `step`: the current step (index of the filtered trace)
  """
  def prev_actor_step(trace, pid, step) do
    raw_step = elem(trace.filtered[step], 1)

    actor_trace(trace, pid)
    |> Enum.filter(fn t -> t <= raw_step end)
    |> Enum.at(-2)
    |> filtered_step_to(trace)
  end

  @spec actor_step_count(t(), Dataspace.actor_id()) :: non_neg_integer()
  @doc """
  Returns the number of steps in the trace for the specified actor.
  """
  def actor_step_count(trace, pid) do
    actor_trace(trace, pid)
    |> Enum.count()
  end

  @spec actor_step_idx(t(), Dataspace.actor_id(), non_neg_integer()) :: non_neg_integer() | nil
  @doc """
  Given a step index in the filtered trace, returns the corresponding index in the trace
  of states for the specified actor.
  Returns nil if there is no state for the actor at the given step.
  """
  def actor_step_idx(trace, pid, step) do
    raw_step = elem(trace.filtered[step], 1)

    actor_trace(trace, pid)
    |> Enum.count(fn t -> t <= raw_step end)
    |> case do
      0 -> nil
      idx -> idx - 1
    end
  end

  @spec filtered_step_to(nil | non_neg_integer(), t()) :: non_neg_integer()
  @doc """
  Returns the step in the filtered trace associated with the given raw trace index.
  """
  def filtered_step_to(nil, _), do: nil

  def filtered_step_to(raw_step, trace) do
    trace.filtered
    |> Enum.map(fn {filtered_step, {_, raw_step}} -> {raw_step, filtered_step} end)
    |> earliest_after(raw_step)
    |> case do
      {_, filtered_step} -> filtered_step
      _ -> nil
    end
  end
end
