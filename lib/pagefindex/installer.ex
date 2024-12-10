defmodule Pagefindex.Installer do
  @moduledoc false

  require Logger

  @latest_version "1.4.0"

  def config(version) when is_binary(version) do
    config(version: version)
  end

  def config(config) when is_list(config) or is_map(config) do
    config
    |> Map.new()
    |> resolve_version()
    |> resolve_os_type()
    |> resolve_target_arch()
    |> resolve_path()
    |> resolve_url()
  end

  def download(%{data: _} = config) do
    downloading(config)
  end

  # coveralls-ignore-start

  def download(config) do
    downloading(config)

    case download_file(config[:url]) do
      {:ok, data} -> Map.put(config, :data, data)
      {:error, reason} -> {:error, reason}
    end
  end

  # coveralls-ignore-stop

  def install({:error, reason}), do: {:error, reason}

  def install(%{data: data} = config) do
    File.mkdir_p(config[:dir])

    case :erl_tar.extract({:binary, data}, [:memory, :compressed]) do
      {:ok, files} -> extract_binary(files, config)
      {:error, reason} -> {:error, "Failed to extract archive: #{inspect(reason)}"}
    end
  end

  defp downloading(config) do
    Logger.info("Downloading pagefind v#{config[:version]} for #{config[:target_arch]}...")
    config
  end

  defp resolve_version(%{version: :latest} = config), do: Map.put(config, :version, @latest_version)
  defp resolve_version(%{version: version} = config), do: Map.put(config, :version, version)
  defp resolve_version(config), do: Map.put(config, :version, @latest_version)

  defp resolve_os_type(%{os_type: {_, _}} = config), do: config
  defp resolve_os_type(config), do: Map.put(config, :os_type, :os.type())

  defp resolve_target_arch(%{target_arch: _} = config), do: config

  defp resolve_target_arch(config) do
    arch =
      :system_architecture
      |> :erlang.system_info()
      |> to_string()
      |> String.split("-")
      |> hd()

    # coveralls-ignore-start

    arch =
      case {arch, :erlang.system_info(:wordsize) * 8} do
        {"x86_64", 64} -> "x86_64"
        {"aarch64", 64} -> "aarch64"
        {"arm64", 64} -> "aarch64"
        _ -> raise "Unsupported architecture: #{arch}"
      end

    target =
      case config[:os_type] do
        {:unix, :darwin} -> "#{arch}-apple-darwin"
        {:unix, :linux} -> "#{arch}-unknown-linux-musl"
        {:win32, _} -> "#{arch}-pc-windows-msvc"
        os -> raise "Unsupported OS: #{inspect(os)}"
      end

    # coveralls-ignore-stop

    Map.put(config, :target_arch, target)
  end

  defp resolve_path(%{binary: path} = config), do: Map.put(config, :dir, Path.dirname(path))

  defp resolve_path(config) do
    name = "pagefind-#{config[:version]}-#{config[:target_arch]}"

    # coveralls-ignore-start

    base_path =
      if Code.ensure_loaded?(Mix.Project) do
        Path.join(Path.dirname(Mix.Project.build_path()), name)
      else
        Path.expand("_build/#{name}")
      end

    # coveralls-ignore-stop

    base_path = Application.get_env(:pagefindex, :path) || base_path

    ext = if match?({:win32, _}, config[:os_type]), do: ".exe", else: ""
    path = Path.join(base_path, "pagefind#{ext}")

    Map.merge(config, %{binary: path, dir: Path.dirname(path)})
  end

  defp resolve_url(%{url: _} = config), do: config

  defp resolve_url(config) do
    Map.put(
      config,
      :url,
      "https://github.com/Pagefind/pagefind/releases/download/v#{config[:version]}/pagefind-v#{config[:version]}-#{config[:target_arch]}.tar.gz"
    )
  end

  # coveralls-ignore-start

  defp download_file(url) do
    {:ok, _} = Application.ensure_all_started([:telemetry, :inets, :ssl])

    case :httpc.request(:get, {to_charlist(url), []}, [{:timeout, 30_000}], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _headers, _body}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, "Download failed: #{inspect(reason)}"}
    end
  end

  # coveralls-ignore-stop

  defp extract_binary(files, %{binary: path} = config) do
    case Enum.find(files, &match_pagefind?/1) do
      {_, file} ->
        if Pagefindex.System.file_exists?(path), do: File.rm!(path)
        File.write!(path, file)
        File.chmod!(path, 0o755)
        {:ok, config}

      nil ->
        {:error, "pagefind binary not found in archive"}
    end
  end

  defp match_pagefind?(file) do
    match?({~c"pagefind", _}, file) or match?({~c"pagefind.exe", _}, file)
  end
end
