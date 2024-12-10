defmodule Pagefindex.Config do
  @moduledoc false

  import UnionTypespec, only: [union_type: 1]

  @run_with [:auto, :bun, :global, :local, :npm, :pnpm]
  union_type run_with_names :: @run_with
  @type run_with :: run_with_names | {:command, [String.t()]}

  @type config :: %{
          args: [String.t()],
          run_with: run_with(),
          version: :latest | String.t()
        }

  @defaults %{args: [], run_with: :auto, version: :latest}

  def new(input \\ []) when is_list(input) or is_map(input) do
    base()
    |> Map.merge(Map.new(input))
    |> validate()
  end

  def base do
    Map.merge(@defaults, Map.new(Application.get_env(:pagefindex, :config, %{})))
  end

  def validate(config) do
    with :ok <- validate_run_with(config[:run_with]),
         :ok <- validate_version(config[:version]),
         :ok <- validate_args(config[:args]) do
      {:ok, config}
    end
  end

  defp validate_run_with(run_with) when run_with in @run_with, do: :ok
  defp validate_run_with({:command, [command | _]}) when is_binary(command), do: :ok

  defp validate_run_with(other) do
    {:error,
     "invalid :run_with value #{inspect(other)}, expected one of #{inspect(@run_with)} or {:command, [\"command\", \"args\", ...]}"}
  end

  defp validate_version(:latest), do: :ok

  defp validate_version(version) when is_binary(version) do
    if Regex.match?(~r/^\d+\.\d+\.\d+(?:-(alpha|beta|rc)\.?\d+)?$/, version) do
      :ok
    else
      {:error, "invalid :version value #{inspect(version)}, expected exact version like \"1.4.0\" or \"1.4.0-alpha.1\""}
    end
  end

  defp validate_version(other) do
    {:error, "invalid :version value #{inspect(other)}, expected :latest or exact version string"}
  end

  defp validate_args(args) when is_list(args), do: :ok

  defp validate_args(other), do: {:error, "invalid :args value #{inspect(other)}, expected list of strings"}
end
