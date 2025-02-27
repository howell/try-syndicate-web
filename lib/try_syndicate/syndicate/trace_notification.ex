defmodule TrySyndicate.Syndicate.TraceNotification do
  alias TrySyndicate.Syndicate.{Dataspace, ActorEnv, Json}

  @fields [:type, :detail]

  @type dataspace_notification() :: %__MODULE__{type: :dataspace, detail: Dataspace.t()}
  @type actors_notification() :: %__MODULE__{type: :actors, detail: ActorEnv.t()}
  @type t() :: dataspace_notification() | actors_notification()

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    with {:error, r1} <- parse_dataspace_notification(json),
         {:error, r2} <- parse_actors_notification(json) do
      {:error, "Invalid trace notification JSON: #{r1} or #{r2}"}
    else
      {:ok, v} -> {:ok, v}
    end
  end

  @spec parse_dataspace_notification(term()) ::
          {:ok, dataspace_notification()} | {:error, String.t()}
  def parse_dataspace_notification(json) do
    if is_map(json) do
      with {:ok, "dataspace"} <- Json.parse_field(json, "type"),
           {:ok, detail} <- Json.parse_field(json, "detail", &Dataspace.from_json/1) do
        {:ok, %__MODULE__{type: :dataspace, detail: detail}}
      else
        {:error, reason} -> {:error, "Invalid dataspace notification JSON: #{reason}"}
        v -> {:error, "Invalid dataspace notification JSON: invalid 'type' field #{inspect(v)}"}
      end
    else
      {:error, "Invalid dataspace notification JSON: not a map"}
    end
  end

  @spec parse_actors_notification(term()) ::
          {:ok, actors_notification()} | {:error, String.t()}
  def parse_actors_notification(json) do
    if is_map(json) do
      with {:ok, "actors"} <- Json.parse_field(json, "type"),
           {:ok, detail} <- Json.parse_field(json, "detail", &ActorEnv.from_json/1) do
        {:ok, %__MODULE__{type: :actors, detail: detail}}
      else
        {:error, reason} -> {:error, "Invalid actors notification JSON: #{reason}"}
        v -> {:error, "Invalid actors notification JSON: invalid 'type' field #{inspect(v)}"}
      end
    else
      {:error, "Invalid actors notification JSON: not a map"}
    end
  end
end
