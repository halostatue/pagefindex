defmodule MockSystem do
  @moduledoc false

  import ExUnit.Assertions

  @type t :: %{
          find: boolean() | nil,
          mode: :bun | :pnpm | :npm | :global | :command | nil,
          status: :ok | :error,
          use_version: nil | binary(),
          version: binary() | pos_integer(),
          command: list(binary()) | nil
        }

  @defaults %{find: false, mode: nil, version: "1.4.0", status: :ok, use_version: nil}

  def prepare(opts \\ []) do
    Process.put(:mock_state, Map.merge(@defaults, Map.new(opts)))
  end

  def cmd("pagefind", ["--version"], _opts) do
    do_version()
  end

  def cmd(command, args, _opts) do
    do_cmd(state!(:mode), command, args)
  end

  def find_executable(_name) do
    if state!(:mode) == :global and state(:find, false) do
      "pagefind"
    end
  end

  def halt(status), do: throw({:halt, status})

  def file_exists?(path) do
    case state(:mode) do
      :bun -> path == "bun.lockb"
      :pnpm -> path == "pnpm-lock.yaml"
      :npm -> path == "package-lock.json"
      _ -> false
    end
  end

  def assert_command(:command, command, args) do
    [expected_command | expected_args] = state!(:command)
    assert expected_command == command

    for expected_arg <- expected_args do
      assert expected_arg in args
    end
  end

  def assert_command(:global, command, _) do
    assert "pagefind" == command
  end

  def assert_command(mode, command, [pagefind | _]) do
    case mode do
      :bun -> assert "bunx" == command
      :pnpm -> assert "pnpx" == command
      :npm -> assert "npx" == command
    end

    if version = state!(:use_version) do
      assert "pagefind@#{version}" == pagefind
    else
      assert "pagefind" == pagefind
    end
  end

  def assert_site(args, site_dir) do
    refute "-s" in args
    assert "--site" in args
    assert site_dir in args
  end

  def assert_extra(args) do
    if extra = state(:extra) do
      for arg <- extra do
        assert arg in args
      end
    end
  end

  defp do_cmd(mode, command, args) do
    assert_command(mode, command, args)

    assert_site(args, state(:site_dir, "_site"))

    assert_extra(args)

    cond do
      "--version" in args -> do_version()
      state(:status) == :ok -> success()
      true -> error()
    end
  end

  defp state! do
    case Process.get(:mock_state) do
      state when is_map(state) and map_size(state) > 0 -> state
      _else -> assert false, "Invalid mock system state."
    end
  end

  defp state!(key) do
    case Map.fetch(state!(), key) do
      {:ok, value} -> value
      :error -> assert false, "Invalid mock system state, missing #{key}."
    end
  end

  defp state(key, default \\ nil) do
    Map.get(state!(), key, default)
  end

  defp do_version do
    case state!(:version) do
      version when is_binary(version) -> {"pagefind #{version}", 0}
      status when is_integer(status) -> {"command not found", status}
    end
  end

  defp success do
    {
      """
      Running Pagefind v1.4.0 (Extended)
      Running from: "/home/pagefindex/goodsite/"
      Source:       "_site"
      Output:       "_site/pagefind"

      [Walking source directory]
      Found 82 files matching **/*.{html}

      [Parsing files]
      Found a data-pagefind-body element on the site.
      ↳ Ignoring pages without this tag.

      [Reading languages]
      Discovered 1 language: en

      [Building search indexes]
      Total:
      Indexed 1 language
      Indexed 46 pages
      Indexed 3810 words
      Indexed 2 filters
      Indexed 0 sorts

      Finished in 0.091 seconds
      """,
      0
    }
  end

  defp error do
    {"""
     Running Pagefind v1.4.0 (Extended)
     Running from: "/home/pagefindex/badsite/
     Source:       ""
     Output:       "pagefind"

     [Walking source directory]
     Found 0 files matching **/*.{html}

     [Parsing files]
     Did not find a data-pagefind-body element on the site.
     ↳ Indexing all <body> elements on the site.

     [Reading languages]
     Discovered 0 languages:

     [Building search indexes]
     Total:
     Indexed 0 languages
     Indexed 0 pages
     Indexed 0 words
     Indexed 0 filters
     Indexed 0 sorts

     Error: Pagefind was not able to build an index.
     Most likely, the directory passed to Pagefind was empty or did not contain any html files.
     """, 1}
  end
end
