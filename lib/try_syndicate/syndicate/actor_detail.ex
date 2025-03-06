defmodule TrySyndicate.Syndicate.ActorDetail do
  alias TrySyndicate.Syndicate.{Facet, Json}

  @type t() :: %__MODULE__{
    facets: %{Facet.fid() => Facet.t()},
    dataflow: dfg()
  }

  @type dfg_id() :: String.t()

  # forward edges of a dataflow graph
  @type dfg() :: %{
    dfg_id() => [dfg_id()]
  }

  @fields [:facets, :dataflow]

  @enforce_keys @fields
  defstruct @fields

  def from_json(json) do
    with {:ok, facets} <- Json.parse_field(json, "facets", &parse_facets/1),
         {:ok, dataflow} <- Json.parse_field(json, "dataflow", &parse_dataflow/1) do
      {:ok, %__MODULE__{facets: facets, dataflow: dataflow}}
    else
      {:error, reason} -> {:error, "Invalid actor detail JSON: #{reason}"}
    end
  end

  @spec parse_facets(term()) :: {:ok, %{Facet.fid() => Facet.t()}} | {:error, String.t()}
  def parse_facets(json) do
    case Json.parse_list(json, &parse_facet/1) do
      {:ok, items} -> {:ok, Map.new(items)}
      {:error, reason} -> {:error, "Invalid actor detail JSON: #{reason}"}
    end
  end

  def parse_facet(json) do
    with {:ok, fid} <- Json.parse_field(json, "facet_id"),
         {:ok, facet} <- Json.parse_field(json, "detail", &Facet.from_json/1) do
      {:ok, {fid, facet}}
    else
      {:error, reason} -> {:error, "Invalid actor detail item: #{reason}"}
    end
  end

  @spec parse_dataflow(term()) :: {:ok, dfg()} | {:error, String.t()}
  def parse_dataflow(json) do
    case Json.parse_list(json, &parse_dataflow_item/1) do
      {:ok, items} -> {:ok, Map.new(items)}
      {:error, reason} -> {:error, "Invalid actor detail JSON: #{reason}"}
    end
  end

  def parse_dataflow_item(json) do
    with {:ok, src} <- Json.parse_field(json, "source"),
         {:ok, dests} <- Json.parse_field(json, "dests", &Json.parse_list/1) do
      {:ok, {src, dests}}
    else
      {:error, reason} -> {:error, "Invalid actor detail item: #{reason}"}
    end
  end
end
