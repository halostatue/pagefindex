defmodule ConfigTest do
  use ExUnit.Case, async: false

  alias Pagefindex.Config

  describe "config/1" do
    test "returns default config" do
      assert {:ok, %{args: [], run_with: :auto, version: :latest}} = Config.new()
    end

    test "accepts keyword list config" do
      assert {:ok, config} = Config.new(run_with: :bun, version: :latest)
      assert config.run_with == :bun
    end

    test "accepts map config" do
      assert {:ok, config} = Config.new(%{run_with: :npm, version: :latest})
      assert config.run_with == :npm
    end

    test "has sensible defaults" do
      assert {:ok, config} = Config.new(%{})
      assert config.run_with == :auto
      assert config.version == :latest
      assert config.args == []
    end

    test "accepts valid run_with atoms" do
      for cmd <- [:auto, :bun, :pnpm, :npm, :global, :local] do
        assert {:ok, config} = Config.new(run_with: cmd)
        assert config.run_with == cmd
      end
    end

    test "accepts custom command tuple" do
      assert {:ok, config} = Config.new(run_with: {:command, ~w[mise run pagefind]})
      assert config.run_with == {:command, ~w[mise run pagefind]}
    end

    test "rejects invalid run_with" do
      assert {:error, message} = Config.new(run_with: :invalid, version: :latest)
      assert message =~ "invalid :run_with value"
    end

    test "rejects invalid custom command format" do
      assert {:error, _} = Config.new(run_with: {:command, "not a list"})
    end

    test "accepts valid version values" do
      for val <- [:latest, "1.4.0", "2.1.3"] do
        assert {:ok, config} = Config.new(version: val)
        assert config.version == val
      end
    end

    test "accepts pre-release versions with dot separator" do
      for val <- ["1.4.0-alpha.1", "2.0.0-beta.5", "1.3.2-rc.3"] do
        assert {:ok, config} = Config.new(version: val)
        assert config.version == val
      end
    end

    test "accepts pre-release versions without dot separator" do
      for val <- ["1.4.0-alpha1", "2.0.0-beta5", "1.3.2-rc3"] do
        assert {:ok, config} = Config.new(version: val)
        assert config.version == val
      end
    end

    test "rejects invalid version formats" do
      invalid_versions = [
        "1.4",           # 2-part version
        "1",             # 1-part version
        "1.4.0-gamma.1", # invalid pre-release type
        "1.4.0-alpha",   # missing pre-release number
        "1.4.0-alpha.a", # non-numeric pre-release
        "v1.4.0",        # version prefix
        "1.4.0.1"        # 4-part version
      ]

      for version <- invalid_versions do
        assert {:error, message} = Config.new(version: version)
        assert message =~ "invalid :version value"
      end
    end

    test "rejects invalid version" do
      assert {:error, message} = Config.new(version: :invalid)
      assert message =~ "invalid :version value"
    end

    test "accepts list args" do
      assert {:ok, config} = Config.new(args: ["--verbose"])
      assert config.args == ["--verbose"]
    end

    test "rejects non-list args" do
      assert {:error, message} = Config.new(args: "--verbose")
      assert message =~ "invalid :args value"
    end
  end
end
