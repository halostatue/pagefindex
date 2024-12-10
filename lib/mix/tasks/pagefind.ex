defmodule Mix.Tasks.Pagefind do
  @shortdoc "Run Pagefind to index the site"

  @moduledoc """
  Run Pagefind to index the site for search.

  ## Usage

  ```console
  $ mix pagefind
  $ mix pagefind --command=bun
  $ mix pagefind --site=dist
  ```

  Uses the same configuration as Pagefindex.Tableau, including run_with
  detection and custom arguments.

  ## Options

  - `--site PATH`: The site directory. If unspecified, defaults to the Tableau site
    configuration or `"_site"`.
  - `--run-with MODE`: Overrides configured run_with detection mode. Valid values are
    `auto`, `bun`, `global`, `local`, `npm`, or `pnpm`.
  - `--use-version VERSION`: Overrides configured version requirement.
  - `--version`: Shows the Pagefindex version, the pagefind version, and
    configured pagefind version (if it differs from the current pagefind version).

  All other options and parameters are passed through to `pagefind`, including `--help`.
  """

  use Mix.Task

  import Pagefindex.System, only: [halt: 1]

  def run(argv) do
    {opts, passthrough_args} = parse_options!(argv)

    if opts[:show_version] do
      show_version_info(opts)
      halt(0)
    end

    config =
      extension_config()
      |> with_site(opts[:site])
      |> with_run_with(opts[:run_with])
      |> with_version(opts[:use_version])
      |> with_passthrough_args(passthrough_args)

    case Pagefindex.pagefind(config) do
      {:ok, output} ->
        Mix.shell().info(output)

      {:error, {_, _, _, _} = result} ->
        message = Pagefindex.format_error_message(result)
        Mix.shell().error(message)
        halt(1)
    end
  end

  defp parse_options!(argv) do
    parse_option!(argv, %{opts: [], args: [], errors: []})
  end

  @opts %{
    "--run-with" => :run_with,
    "--site" => :site,
    "--use-version" => :use_version
  }

  defp parse_option!([], %{errors: []} = acc), do: {Enum.reverse(acc.opts), Enum.reverse(acc.args)}

  defp parse_option!([], %{errors: errors}) do
    count = length(errors)
    error = if(count == 1, do: "error", else: "errors")

    raise OptionParser.ParseError, "#{count} #{error} found!\n#{Enum.join(errors, "\n")}"
  end

  for {option, key} <- @opts do
    defp parse_option!([unquote(option)], acc) do
      parse_option!([], %{acc | errors: ["#{unquote(option)} : missing string argument" | acc.errors]})
    end

    defp parse_option!([unquote(option), "--" <> _ | rest], acc) do
      parse_option!(rest, %{acc | errors: ["#{unquote(option)} : missing string argument" | acc.errors]})
    end

    defp parse_option!([unquote("#{option}=") <> value | rest], acc) do
      parse_option!(rest, %{acc | opts: [{unquote(key), value} | acc.opts]})
    end

    defp parse_option!([unquote(option), value | rest], acc) do
      parse_option!(rest, %{acc | opts: [{unquote(key), value} | acc.opts]})
    end
  end

  defp parse_option!(["--version" | rest], acc) do
    parse_option!(rest, %{acc | opts: [{:show_version, true} | acc.opts]})
  end

  defp parse_option!(["--" | rest], acc) do
    parse_option!([], %{acc | args: Enum.reverse(rest, acc.args)})
  end

  defp parse_option!([arg | rest], acc) do
    parse_option!(rest, %{acc | args: [arg | acc.args]})
  end

  defp extension_config do
    case Pagefindex.config() do
      {:ok, config} ->
        config

      {:error, reason} ->
        Mix.shell().error("Configuration error: #{reason}")
        halt(1)
    end
  end

  defp with_site(config, site) do
    Map.put(config, :site, site || "_site")
  end

  @run_with %{
    "auto" => :auto,
    "bun" => :bun,
    "pnpm" => :pnpm,
    "npm" => :npm,
    "global" => :global,
    "local" => :local
  }

  defp run_with, do: @run_with

  defp with_run_with(config, nil), do: config

  defp with_run_with(config, value) do
    case Map.fetch(run_with(), value) do
      {:ok, value} ->
        Map.put(config, :run_with, value)

      :error ->
        Mix.shell().error("Invalid run_with: #{value}. Valid options: #{Enum.map_join(run_with(), ", ", &elem(&1, 0))}")
        halt(1)
    end
  end

  defp with_version(config, nil), do: config
  defp with_version(config, version), do: Map.put(config, :version, version)

  defp with_passthrough_args(config, []), do: config

  defp with_passthrough_args(config, passthrough_args) do
    Map.update(config, :args, passthrough_args, &(&1 ++ passthrough_args))
  end

  defp show_version_info(opts) do
    pagefindex_version =
      :pagefindex
      |> Application.spec(:vsn)
      |> to_string()

    Mix.shell().info("Pagefindex version: #{pagefindex_version}")

    config =
      extension_config()
      |> with_run_with(opts[:run_with])
      |> with_version(opts[:use_version])

    case Pagefindex.pagefind_version(config) do
      {:ok, actual_version} ->
        Mix.shell().info("Pagefind version: #{actual_version}")

        if config.version != :latest and config.version != actual_version do
          Mix.shell().info("Configured version: #{config.version}")
        end

      {:error, reason} ->
        Mix.shell().info("Pagefind: #{reason}")

        if config.version != :latest do
          Mix.shell().info("Configured version: #{config.version}")
        end
    end
  end
end
