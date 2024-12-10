defmodule PagefindexTest do
  use ExUnit.Case, async: false

  describe "pagefind/1" do
    setup do
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      on_exit(fn ->
        Application.delete_env(:pagefindex, :system_impl)
        Application.delete_env(:pagefindex, :config)
      end)

      :ok
    end

    test "runs successfully with auto run_with detection" do
      MockSystem.prepare(mode: :global, find: true, status: :ok)
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :auto, version: :latest, args: [], site: "_site"}
      assert {:ok, output} = Pagefindex.pagefind(config)
      assert output =~ "Running Pagefind v1.4.0"
    end

    test "returns error on command failure" do
      MockSystem.prepare(mode: :global, find: true, status: :error)
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: :latest, args: [], site: "_site"}
      assert {:error, {_cmd, _args, _output, 1}} = Pagefindex.pagefind(config)
    end

    test "uses bunx command when specified" do
      MockSystem.prepare(mode: :bun)
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :bun, version: :latest, args: [], site: "_site"})
    end

    test "uses bunx command with version when specified" do
      MockSystem.prepare(mode: :bun, use_version: "1.3.0")
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :bun, version: "1.3.0", args: [], site: "_site"})
    end

    test "uses pnpmx command when specified" do
      MockSystem.prepare(mode: :pnpm)
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :pnpm, version: :latest, args: [], site: "_site"})
    end

    test "uses npmx command when specified" do
      MockSystem.prepare(mode: :npm)
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :npm, version: :latest, args: [], site: "_site"})
    end

    test "uses global command when specified" do
      MockSystem.prepare(mode: :global, find: true)
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: :latest, args: [], site: "_site"}
      assert {:ok, _} = Pagefindex.pagefind(config)
    end

    test "warns when installed version is newer than configured" do
      import ExUnit.CaptureLog

      MockSystem.prepare(mode: :global, find: true, status: :ok, version: "1.4.0")
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      log =
        capture_log(fn ->
          config = %{run_with: :global, version: "1.3.0", args: [], site: "_site"}
          assert {:ok, _} = Pagefindex.pagefind(config)
        end)

      assert log =~ "pagefind version 1.4.0 is newer than configured version 1.3.0"
    end

    test "errors when installed version is older than configured" do
      MockSystem.prepare(mode: :global, find: true, status: :ok, version: "1.2.0")
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: "1.3.0", args: [], site: "_site"}
      assert {:error, "pagefind version 1.2.0 is older than required version 1.3.0"} = Pagefindex.pagefind(config)
    end

    test "errors when installed version has different major version" do
      MockSystem.prepare(mode: :global, find: true, status: :ok, version: "2.0.0")
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: "1.4.0", args: [], site: "_site"}
      assert {:error, "pagefind major version 2 does not match required major version 1"} = Pagefindex.pagefind(config)
    end

    test "uses custom command when specified" do
      MockSystem.prepare(mode: :command, command: ["mise", "run", "pagefind"])
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: {:command, ["mise", "run", "pagefind"]}, args: [], site: "_site"}
      assert {:ok, _} = Pagefindex.pagefind(config)
    end

    test "includes additional args" do
      MockSystem.prepare(mode: :global, find: true, extra: ["--verbose", "--force-language", "en"])
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: :latest, args: ["--verbose", "--force-language", "en"], site: "_site"}
      assert {:ok, _} = Pagefindex.pagefind(config)
    end

    test "filters out existing --site args" do
      MockSystem.prepare(mode: :global, find: true)
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: :latest, args: ["--site", "old", "--verbose"], site: "_site"}
      assert {:ok, _} = Pagefindex.pagefind(config)
    end

    test "filters out existing -s args" do
      MockSystem.prepare(mode: :global, find: true)
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      config = %{run_with: :global, version: :latest, args: ["-s", "old", "--verbose"], site: "_site"}
      assert {:ok, _} = Pagefindex.pagefind(config)
    end
  end

  describe "format_success_message/1" do
    @pagefind_output """
    Running Pagefind v1.4.0 (Extended)
    Running from: "/home/tableau/pagefind/site"
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
    """

    test "formats single indexed line" do
      output = "Indexed 5 pages"
      assert Pagefindex.format_success_message(output) == "5 pages"
    end

    test "formats multiple indexed lines" do
      result = Pagefindex.format_success_message(@pagefind_output)
      assert result == "1 language, 46 pages, 3810 words, and 2 filters"
    end

    test "handles output with no indexed lines" do
      output = "No indexable content found"
      assert Pagefindex.format_success_message(output) == "No output"
    end

    test "filters out zero entries but keeps non-zero" do
      output = """
      Indexed 3 sorts
      Indexed 0 filters
      Indexed 10 pages
      """

      result = Pagefindex.format_success_message(output)
      assert result == "3 sorts and 10 pages"
    end
  end

  describe "format_error_message/2" do
    test "formats error message" do
      result = {"pagefind", ["--site", "_site"], "Error output", 1}

      message = Pagefindex.format_error_message(result)

      assert message =~ "[Pagefindex] Failed with exit code 1"
      assert message =~ "Command: pagefind --site _site"
      assert message =~ "Error output"
    end
  end

  describe "auto command detection with lockfiles" do
    setup do
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      :ok
    end

    test "detects bun when bun.lockb exists" do
      MockSystem.prepare(mode: :bun)
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :auto, version: :latest, args: [], site: "_site"})
    end

    test "detects pnpm when pnpm-lock.yaml exists" do
      MockSystem.prepare(mode: :pnpm)

      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :auto, version: :latest, args: [], site: "_site"})
    end

    test "detects npm when package-lock.json exists" do
      MockSystem.prepare(mode: :npm)
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :auto, version: :latest, args: [], site: "_site"})
    end

    test "falls back to global when no lockfiles exist" do
      MockSystem.prepare(mode: :global, find: true)
      assert {:ok, _} = Pagefindex.pagefind(%{run_with: :auto, version: :latest, args: [], site: "_site"})
    end

    test "returns error when no pagefind installation found" do
      MockSystem.prepare(mode: nil, find: false)
      config = %{run_with: :auto, version: :latest, args: [], site: "_site"}
      assert {:error, "No pagefind installation found"} = Pagefindex.pagefind(config)
    end
  end

  describe "pagefind_version/1" do
    setup do
      Application.put_env(:pagefindex, :system_impl, MockSystem)

      on_exit(fn ->
        Application.delete_env(:pagefindex, :system_impl)
      end)

      :ok
    end

    test "returns version for global pagefind" do
      MockSystem.prepare(mode: :global, find: true, version: "1.4.0")
      config = %{run_with: :global, version: :latest}
      assert {:ok, "1.4.0"} = Pagefindex.pagefind_version(config)
    end

    test "returns error when pagefind not found" do
      MockSystem.prepare(mode: :global, find: false)
      config = %{run_with: :global, version: :latest}
      assert {:error, "pagefind not found in PATH"} = Pagefindex.pagefind_version(config)
    end

    test "returns error when version command fails" do
      MockSystem.prepare(mode: :global, find: true, version: 127)
      config = %{run_with: :global, version: :latest}
      assert {:error, "failed to get version: command not found"} = Pagefindex.pagefind_version(config)
    end

    test "returns error when version output is unparseable" do
      MockSystem.prepare(mode: :global, find: true, version: "unparseable output")
      config = %{run_with: :global, version: :latest}
      assert {:error, "could not parse version from: " <> _} = Pagefindex.pagefind_version(config)
    end
  end

  describe "configuration merging" do
    setup do
      on_exit(fn -> Application.delete_env(:pagefindex, :config) end)

      :ok
    end

    test "merges application config with defaults" do
      Application.put_env(:pagefindex, :config, %{run_with: :npm, args: ["--verbose"]})
      assert {:ok, %{args: ["--verbose"], run_with: :npm, version: :latest}} = Pagefindex.config()
    end

    test "merges keyword list config" do
      Application.put_env(:pagefindex, :config, %{run_with: :global})
      assert {:ok, config} = Pagefindex.config(args: ["--verbose"])
      # from app config
      assert config.run_with == :global
      # from parameter
      assert config.args == ["--verbose"]
    end

    test "validation errors propagate through config/1" do
      assert {:error, message} = Pagefindex.config(run_with: :invalid)
      assert message =~ "invalid :run_with value"
    end

    test "validates custom command with empty args list" do
      assert {:error, _} = Pagefindex.config(run_with: {:command, []})
    end

    test "validates version with invalid format" do
      assert {:error, message} = Pagefindex.config(version: "invalid")
      assert message =~ "invalid :version value"
    end
  end
end
