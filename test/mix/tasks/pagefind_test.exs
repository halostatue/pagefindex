defmodule Mix.Tasks.PagefindTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Pagefind, as: PagefindTask

  setup do
    original_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    MockSystem.prepare(mode: :global, find: true, status: :ok)
    Application.put_env(:pagefindex, :system_impl, MockSystem)

    on_exit(fn ->
      Mix.shell(original_shell)
      Application.delete_env(:pagefindex, :system_impl)
      Application.delete_env(:pagefindex, :config)
    end)

    :ok
  end

  test "runs successfully with default configuration" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)
    assert_task([])
    assert_shell_info("Indexed 46 pages")
  end

  test "uses custom site directory from --site option" do
    MockSystem.prepare(mode: :global, find: true, site_dir: "custom_site")

    assert_task(["--site", "custom_site"])
    assert_shell_info("Indexed 46 pages")
  end

  test "overrides command with --run-with option" do
    MockSystem.prepare(mode: :bun)
    Application.put_env(:pagefindex, :config, %{run_with: :npm, version: :latest})

    assert_task(["--run-with", "bun"])
    assert_shell_info("Indexed 46 pages")
  end

  test "uses extension configuration args" do
    MockSystem.prepare(mode: :global, find: true, extra: ["--verbose", "--force-language", "en"])
    Application.put_env(:pagefindex, :config, %{args: ["--verbose", "--force-language", "en"]})

    assert_task([])
    assert_shell_info("Indexed 46 pages")
  end

  for run_with <- ["auto", "bun", "global", "npm", "pnpm"] do
    test "accepts --run-with #{run_with}" do
      run_with = unquote(run_with)

      if run_with in ["auto", "global"] do
        MockSystem.prepare(mode: :global, find: true)
      else
        MockSystem.prepare(mode: String.to_existing_atom(run_with))
      end

      Application.put_env(:pagefindex, :config, %{run_with: :auto, version: :latest})

      assert_task(["--run-with", run_with])
      assert_shell_info("Indexed 46 pages")
    end
  end

  test "shows an error when pagefind version can't be returned" do
    MockSystem.prepare(mode: :global, find: true, version: 127)
    assert_task(["--version"], 0)
    assert_shell_info(["Pagefindex version:", "Pagefind: failed to get version:"])
  end

  test "shows an error when pagefind version can't be returned (not latest)" do
    Application.put_env(:pagefindex, :config, %{version: "1.3.0"})
    MockSystem.prepare(mode: :global, find: true, version: 127)
    assert_task(["--version"], 0)
    assert_shell_info(["Pagefindex version:", "Pagefind: failed to get version:", "Configured version:"])
  end

  test "shows version info with --version" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)
    assert_task(["--version"], 0)
    assert_shell_info(["Pagefindex version:", "Pagefind version:"])
  end

  test "shows configured version with --version when it doesn't match" do
    Application.put_env(:pagefindex, :config, %{version: "1.3.0"})
    MockSystem.prepare(mode: :global, find: true, status: :ok)
    assert_task(["--version"], 0)
    assert_shell_info(["Pagefindex version:", "Pagefind version:", "Configured version:"])
  end

  test "handles configuration error" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)
    Application.put_env(:pagefindex, :config, %{version: :invalid})

    assert_task([], 1)
    assert_shell_error("Configuration error:")
  end

  test "handles invalid run_with option" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_task(["--run-with", "invalid"], 1)
    assert_shell_error("Invalid run_with: invalid")
  end

  test "allows --use-version with value" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_task(["--use-version", "1.4.0"])
    assert_shell_info("Indexed 46 pages")
  end

  test "handles tuple error from pagefind" do
    MockSystem.prepare(mode: :global, find: true, status: :error)

    assert_task([], 1)
    assert_shell_error("[Pagefindex] Failed with exit code 1")
  end

  test "passes through additional arguments" do
    MockSystem.prepare(mode: :global, find: true, extra: ["--verbose", "--force-language", "en"])

    assert_task(["--verbose", "--force-language", "en"])
    assert_shell_info("Indexed 46 pages")
  end

  test "sets custom site directory" do
    MockSystem.prepare(mode: :global, find: true, site_dir: "custom_site")

    assert_task(["--site", "custom_site"])
    assert_shell_info("Indexed 46 pages")
  end

  test "sets custom version" do
    MockSystem.prepare(mode: :global, find: true, version: "1.5.0")

    assert_task(["--use-version", "1.5.0"])
    assert_shell_info("Indexed 46 pages")
  end

  defp flush_shell_messages do
    receive do
      {:mix_shell, :info, [msg]} -> [{:info, msg} | flush_shell_messages()]
      {:mix_shell, :error, [msg]} -> [{:error, msg} | flush_shell_messages()]
    after
      0 -> []
    end
  end

  defp assert_shell_info(expected) do
    expected = List.wrap(expected)
    messages = flush_shell_messages()

    for expect <- expected do
      assert Enum.find(messages, fn {type, msg} -> type == :info and String.contains?(msg, expect) end),
             "Expected shell info containing: #{expect}\nActual messages: #{inspect(messages)}"
    end
  end

  defp assert_shell_error(expected) do
    expected = List.wrap(expected)
    messages = flush_shell_messages()

    for expect <- expected do
      assert Enum.find(messages, fn {type, msg} -> type == :error and String.contains?(msg, expect) end),
             "Expected shell error containing: #{expect}\nActual messages: #{inspect(messages)}"
    end
  end

  # Tests for uncovered lines - focusing on later lines first

  test "handles version info error in show_version_info" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)
    Application.put_env(:pagefindex, :config, %{version: :invalid})

    assert_task(["--version"], 1)
    assert_shell_error("invalid :version value :invalid")
  end

  test "handles missing argument for --site option" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_raise OptionParser.ParseError, "1 error found!\n--site : missing string argument", fn ->
      assert_task(["--site"])
    end
  end

  test "handles missing argument for --run-with option" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_raise OptionParser.ParseError, "1 error found!\n--run-with : missing string argument", fn ->
      assert_task(["--run-with"])
    end
  end

  test "handles missing argument for --use-version option" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_raise OptionParser.ParseError, "1 error found!\n--use-version : missing string argument", fn ->
      assert_task(["--use-version"])
    end
  end

  test "handles multiple parsing errors" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    # The parser will stop at the first error, so this will only report the --site error
    assert_raise OptionParser.ParseError, "1 error found!\n--site : missing string argument", fn ->
      assert_task(["--site", "--run-with"])
    end
  end

  test "handles option followed by another option (missing argument)" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_raise OptionParser.ParseError, "1 error found!\n--site : missing string argument", fn ->
      assert_task(["--site", "--version"])
    end
  end

  test "handles option followed by double dash (missing argument)" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    assert_raise OptionParser.ParseError, "1 error found!\n--site : missing string argument", fn ->
      assert_task(["--site", "--"])
    end
  end

  test "handles double dash separator for passthrough args" do
    MockSystem.prepare(mode: :global, find: true, extra: ["--verbose", "--force-language", "en"])

    assert_task(["--", "--verbose", "--force-language", "en"])
    assert_shell_info("Indexed 46 pages")
  end

  test "handles option with equals syntax" do
    MockSystem.prepare(mode: :global, find: true, site_dir: "custom_site")

    assert_task(["--site=custom_site"])
    assert_shell_info("Indexed 46 pages")
  end

  test "handles multiple parsing errors with custom parser" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    # Create a scenario that generates multiple errors by manually building the error list
    # This tests the "errors" plural case in parse_option!
    assert_raise OptionParser.ParseError, ~r/2 errors found/, fn ->
      # This is tricky - we need to trigger multiple errors in one parse
      # Let's try with multiple missing arguments that get accumulated
      assert_task(["--site", "--run-with", "--use-version"])
    end
  end

  test "handles option followed by double dash terminator" do
    MockSystem.prepare(mode: :global, find: true, status: :ok)

    # This should hit the "--" | rest pattern in parse_option!
    assert_raise OptionParser.ParseError, "1 error found!\n--run-with : missing string argument", fn ->
      assert_task(["--run-with", "--"])
    end
  end

  defp assert_task(args, exit_code \\ nil) do
    if exit_code do
      assert {:halt, exit_code} == catch_throw(PagefindTask.run(args))
    else
      assert :ok == PagefindTask.run(args)
    end
  end
end
