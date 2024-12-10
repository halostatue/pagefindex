defmodule Pagefindex do
  @moduledoc """
  Pagefindex runs [Pagefind][0] search indexing.

  Pagefind is a static search library that creates a search index from generated HTML,
  making it perfect for static site generators. It has explicit support for [tableau][1],
  but should work with [Fermo][2], [Griffin SSG][3], [Dragon][4], [Postex][5],
  [NimblePublisher][6], [Tale][7], or other BEAM-based static site generators.

  [0]: https://pagefind.app
  [1]: https://github.com/elixir-tools/tableau
  [2]: https://github.com/joeyates/fermo
  [3]: https://github.com/elixir-griffin/griffin
  [4]: https://github.com/srevenant/dragon
  [5]: https://github.com/alanvardy/postex
  [6]: https://github.com/dashbitco/nimble_publisher
  [7]: https://github.com/Willyboar/tale

  Pagefindex provides functionality to run Pagefind programmatically. It will take
  advantage of installed JavaScript runtimes and package managers (`bunx`, `pnpx`, and
  `npx`), a global installation of Pagefind, or will automatically install Pagefind as
  part of the project.

  ## Configuration

  ```elixir
  configure :pagefindex, :config,
    run_with: :auto,
    args: [],
    on_error: :warn,
    site: "_site"
  ```

  - `:site` (required): Path of the site directory to index.

  - `:run_with` (default `:auto`): Command detection mode or specific command.

    - `:auto`: Auto-detect based on JavaScript package lockfiles, `:global` or `:local`.

      Auto detection decides between `:bun`, `:pnpm`, `:npm`, `:global`, and `:local` by
      looking for lockfiles in the current directory: `bun.lockb` (`:bun`),
      `pnpm-lock.yaml` (`:pnpm`), `package-lock.json` (`:npm`). If no lockfiles are found,
      `:global` (if `pagefind` is found in `$PATH`) or `:local` (download and install)
      will be used.

    - `:bun`:  Forces Bun with `bunx pagefind`
    - `:pnpm`: Forces PNPM usage with `pnpx pagefind`
    - `:npm`: Forces NPM usage with `npx pagefind`
    - `:global`: Forces the use of `pagefind` from `$PATH`
    - `:local`: Downloads and uses a local pagefind binary

    - `{:command, args}`: Uses a custom command list to run Pagefind. For example, if you
      have a [mise](https://mise.jdx.dev) task defined to run Pagefind, you might use
      `{:command, ["mise", "run", "pagefind"]}`. See notes on `:args` for specific
      processing details.


  - `:version` (default `:latest`): Version requirement for pagefind. Accepts `:latest`,
    exact versions like `"1.4.0"`, or simple requirements like `"~> 1.4"` or `">= 1.3.1"`.
    Used with `:bun`, `:pnpm`, `:npm`, `:global`, and `:local` modes.

  - `:args` (default `[]`): Additional arguments passed to Pagefind.

    Any `--site` (`-s`) flags are removed to prevent conflicts with the ones provided by
    `:site` configuration.

    ```elixir
    config :pagefindex, :config,
      args: ["--verbose", "--force-language", "en"]
    ```


  """

  import Pagefindex.System

  alias Pagefindex.Installer

  require Logger

  @doc """
  Merges and validates configuration options. Returns `{:ok, config}` or
  `{:error, reason}`.

  The configuration will be set from the merged result of default values,
  `Application.get_env(:pagefindex, :config)`, and the provided configuration value.
  """
  defdelegate config(input \\ []), to: Pagefindex.Config, as: :new

  @doc """
  Gets the version of the resolved pagefind binary. Returns `{:ok, version}` or
  `{:error, reason}`.
  """
  def pagefind_version(config) do
    case resolve_run_with(config, validate: false) do
      {:ok, {binary, _}} -> do_pagefind_version(binary)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs Pagefind with the given configuration. Returns `{:ok, output}` or
  `{:error, reason}`.
  """
  def pagefind(config) do
    with {:ok, {command, base_args}} <- resolve_run_with(config) do
      args = filter_site_args(base_args) ++ ["--site", config.site] ++ filter_site_args(config.args)
      run_command(command, args)
    end
  end

  @doc false
  def format_success_message(output) when is_binary(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.match?(&1, ~r/^\s*Indexed\s+[1-9]\d*\s+\w/))
    |> Enum.map(&String.replace(&1, ~r/\s*Indexed /, ""))
    |> do_format_success_message()
  end

  @doc false
  def format_error_message({command, args, output, exit_code}) do
    """
    [Pagefindex] Failed with exit code #{exit_code}
    Command: #{Enum.join([command | args], " ")}
    Output:

    #{output}
    """
  end

  defp do_format_success_message([]), do: "No output"
  defp do_format_success_message([line]), do: line
  defp do_format_success_message([first, second]), do: "#{first} and #{second}"

  defp do_format_success_message(lines) do
    [last | first] = Enum.reverse(lines)

    first =
      first
      |> Enum.reverse()
      |> Enum.join(", ")

    "#{first}, and #{last}"
  end

  defp validate_global_version(binary, version) do
    with {:ok, found} <- do_pagefind_version(binary) do
      case version_compatibility(found, version) do
        :ok ->
          {:ok, {binary, []}}

        {:warn, message} ->
          Logger.warning(message)
          {:ok, {binary, []}}

        {:error, message} ->
          {:error, message}
      end
    end
  end

  defp version_compatibility(_found, :latest), do: :ok

  defp version_compatibility(found, requirement) when is_binary(requirement) do
    found_version = Version.parse!(found)
    req_version = Version.parse!(requirement)

    cond do
      found_version.major != req_version.major ->
        {:error,
         "pagefind major version #{found_version.major} does not match required major version #{req_version.major}"}

      Version.compare(found_version, req_version) == :lt ->
        {:error, "pagefind version #{found} is older than required version #{requirement}"}

      Version.compare(found_version, req_version) == :gt ->
        {:warn, "pagefind version #{found} is newer than configured version #{requirement}"}

      true ->
        :ok
    end
  end

  defp pagefind_with_version(base, :latest), do: [base]
  defp pagefind_with_version(base, version) when is_binary(version), do: ["#{base}@#{version}"]

  defp filter_site_args(args), do: filter_site_args(args, [])

  defp filter_site_args([], new), do: Enum.reverse(new)
  defp filter_site_args(["--site", _next | old], new), do: filter_site_args(old, new)
  defp filter_site_args(["-s", _next | old], new), do: filter_site_args(old, new)
  defp filter_site_args([arg | old], new), do: filter_site_args(old, [arg | new])

  defp resolve_auto_run_with(config, opts) do
    cond do
      file_exists?("bun.lockb") ->
        {:ok, {"bunx", pagefind_with_version("pagefind", config.version)}}

      file_exists?("pnpm-lock.yaml") ->
        {:ok, {"pnpx", pagefind_with_version("pagefind", config.version)}}

      file_exists?("package-lock.json") ->
        {:ok, {"npx", pagefind_with_version("pagefind", config.version)}}

      true ->
        case resolve_global_run_with(config, opts) do
          {:ok, result} -> {:ok, result}
          {:error, _} -> {:error, "No pagefind installation found"}
        end
    end
  end

  defp resolve_global_run_with(config, opts) do
    case find_global_pagefind() do
      {:ok, binary} ->
        if Keyword.get(opts, :validate, true) do
          validate_global_version(binary, config.version)
        else
          {:ok, {binary, []}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_global_pagefind do
    case find_executable("pagefind") do
      nil -> {:error, "pagefind not found in PATH"}
      binary -> {:ok, binary}
    end
  end

  defp run_command(command, args) do
    case cmd(command, args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, exit_code} -> {:error, {command, args, output, exit_code}}
    end
  end

  defp resolve_run_with(config, opts \\ []) do
    case config.run_with do
      value when value in [nil, :auto] -> resolve_auto_run_with(config, opts)
      :bun -> {:ok, {"bunx", pagefind_with_version("pagefind", config.version)}}
      :pnpm -> {:ok, {"pnpx", pagefind_with_version("pagefind", config.version)}}
      :npm -> {:ok, {"npx", pagefind_with_version("pagefind", config.version)}}
      :global -> resolve_global_run_with(config, opts)
      # coveralls-ignore-next-line
      :local -> resolve_local_run_with(config, opts)
      {:command, [command | args]} -> {:ok, {command, args}}
    end
  end

  defp parse_version({output, 0}) do
    trimmed = String.trim(output)

    case Regex.run(~r/(?:pagefind )?(\d+\.\d+\.\d+)/, trimmed, capture: :all_but_first) do
      [version] -> {:ok, version}
      _ -> {:error, "could not parse version from: #{inspect(trimmed)}"}
    end
  end

  defp parse_version({output, _}) do
    {:error, "failed to get version: #{output}"}
  end

  defp do_pagefind_version_with_args(command, args) do
    command
    |> cmd(args, stderr_to_stdout: true)
    |> parse_version()
  end

  defp do_pagefind_version(binary) do
    do_pagefind_version_with_args(binary, ["--version"])
  end

  # coveralls-ignore-start

  defp resolve_local_run_with(config, _opts) do
    case ensure_local_pagefind(config.version) do
      {:ok, %{binary: path}} -> {:ok, {path, []}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_local_pagefind(version) do
    config = Installer.config(version)

    if file_exists?(config.binary) do
      {:ok, config}
    else
      config
      |> Installer.download()
      |> Installer.install()
    end
  end

  # coveralls-ignore-stop
end
