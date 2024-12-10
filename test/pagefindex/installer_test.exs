defmodule Pagefindex.InstallerTest do
  use ExUnit.Case, async: false

  alias Pagefindex.Installer

  @unix_tarball "test/fixtures/pagefind-unix.tar.gz"
  @windows_tarball "test/fixtures/pagefind-windows.tar.gz"

  setup do
    on_exit(fn ->
      Application.delete_env(:pagefindex, :path)
    end)

    :ok
  end

  describe "config/1" do
    test "resolves version from binary string" do
      config = Installer.config("1.3.0")
      assert config[:version] == "1.3.0"
    end

    test "resolves version from :latest atom" do
      config = Installer.config(version: :latest)
      assert config[:version] == "1.4.0"
    end

    test "defaults to latest version when not specified" do
      config = Installer.config(%{})
      assert config[:version] == "1.4.0"
    end

    test "preserves existing version" do
      config = Installer.config(%{version: "1.2.0"})
      assert config[:version] == "1.2.0"
    end

    test "resolves OS type from system" do
      config = Installer.config(%{})
      assert config[:os_type] == :os.type()
    end

    test "preserves existing OS type" do
      config = Installer.config(%{os_type: {:unix, :linux}})
      assert config[:os_type] == {:unix, :linux}
    end

    test "resolves target architecture for current system" do
      config = Installer.config(%{})
      assert config[:target_arch] =~ ~r/^(x86_64|aarch64)-(apple-darwin|unknown-linux-musl|pc-windows-msvc)$/
    end

    test "preserves existing target architecture" do
      config = Installer.config(%{target_arch: "x86_64-apple-darwin"})
      assert config[:target_arch] == "x86_64-apple-darwin"
    end

    test "raises on unsupported OS" do
      assert_raise RuntimeError, ~r/Unsupported OS/, fn ->
        Installer.config(%{os_type: {:unix, :freebsd}})
      end
    end

    test "resolves binary path from custom binary" do
      config = Installer.config(%{binary: "/custom/path/pagefind"})
      assert config[:dir] == "/custom/path"
      assert config[:binary] == "/custom/path/pagefind"
    end

    @tag :tmp_dir
    test "resolves binary path with custom base path", %{tmp_dir: tmp_dir} do
      Application.put_env(:pagefindex, :path, tmp_dir)

      config = Installer.config(%{version: "1.3.0", target_arch: "x86_64-apple-darwin"})
      expected_path = Path.join(tmp_dir, "pagefind")

      assert config[:binary] == expected_path
      assert config[:dir] == tmp_dir
    end

    test "adds .exe extension on Windows" do
      config =
        Installer.config(%{
          version: "1.3.0",
          os_type: {:win32, :nt},
          target_arch: "x86_64-pc-windows-msvc"
        })

      assert String.ends_with?(config[:binary], "pagefind.exe")
    end

    test "resolves download URL" do
      config = Installer.config(%{version: "1.3.0", target_arch: "x86_64-apple-darwin"})

      expected_url =
        "https://github.com/CloudCannon/pagefind/releases/download/v1.3.0/pagefind-v1.3.0-x86_64-apple-darwin.tar.gz"

      assert config[:url] == expected_url
    end

    test "preserves existing URL" do
      config = Installer.config(%{url: "https://custom.url/pagefind.tar.gz"})
      assert config[:url] == "https://custom.url/pagefind.tar.gz"
    end
  end

  describe "download/1" do
    test "skips download when data is already present" do
      config = %{data: "existing_data", version: "1.3.0", target_arch: "x86_64-apple-darwin"}
      result = Installer.download(config)

      assert result == config
    end
  end

  describe "install/1" do
    @describetag :tmp_dir
    test "propagates error tuples" do
      result = Installer.install({:error, "some error"})
      assert result == {:error, "some error"}
    end

    test "extracts and installs pagefind binary", %{tmp_dir: tmp_dir} do
      tarball_data = File.read!(@unix_tarball)

      config = %{
        data: tarball_data,
        binary: Path.join(tmp_dir, "pagefind"),
        dir: tmp_dir
      }

      assert {:ok, ^config} = Installer.install(config)
      assert File.exists?(config[:binary])
      assert File.read!(config[:binary]) =~ "fake pagefind binary"

      stat = File.stat!(config[:binary])
      assert Bitwise.band(stat.mode, 0o111) != 0
    end

    test "extracts and installs pagefind.exe binary on Windows", %{tmp_dir: tmp_dir} do
      tarball_data = File.read!(@windows_tarball)

      config = %{
        data: tarball_data,
        binary: Path.join(tmp_dir, "pagefind.exe"),
        dir: tmp_dir
      }

      assert {:ok, ^config} = Installer.install(config)
      assert File.exists?(config[:binary])
      assert File.read!(config[:binary]) =~ "fake pagefind.exe binary"
    end

    test "overwrites existing binary", %{tmp_dir: tmp_dir} do
      binary_path = Path.join(tmp_dir, "pagefind")
      File.write!(binary_path, "old content")

      tarball_data = File.read!(@unix_tarball)

      config = %{
        data: tarball_data,
        binary: binary_path,
        dir: tmp_dir
      }

      assert {:ok, ^config} = Installer.install(config)
      assert File.read!(binary_path) =~ "fake pagefind binary"
    end

    test "returns error when pagefind binary not found in archive", %{tmp_dir: tmp_dir} do
      empty_tar = Path.join(tmp_dir, "empty.tar.gz")
      :ok = :erl_tar.create(empty_tar, [], [:compressed])
      tarball_data = File.read!(empty_tar)

      config = %{
        data: tarball_data,
        binary: Path.join(tmp_dir, "pagefind"),
        dir: tmp_dir
      }

      assert {:error, "pagefind binary not found in archive"} = Installer.install(config)
    end

    test "returns error when tar extraction fails", %{tmp_dir: tmp_dir} do
      config = %{
        data: "invalid tar data",
        binary: Path.join(tmp_dir, "pagefind"),
        dir: tmp_dir
      }

      assert {:error, error_msg} = Installer.install(config)
      assert error_msg =~ "Failed to extract archive:"
    end
  end

  describe "integration tests" do
    test "full config resolution pipeline" do
      config = Installer.config(%{version: "1.2.0", os_type: {:unix, :darwin}})

      assert config[:version] == "1.2.0"
      assert config[:os_type] == {:unix, :darwin}
      assert config[:target_arch] =~ ~r/aarch64-apple-darwin/
      assert config[:binary]
      assert config[:dir]
      assert config[:url] =~ "v1.2.0"
    end

    @tag :tmp_dir
    test "end-to-end install with custom path", %{tmp_dir: tmp_dir} do
      Application.put_env(:pagefindex, :path, tmp_dir)

      tarball_data = File.read!(@unix_tarball)

      config =
        %{version: "1.3.0"}
        |> Installer.config()
        |> Map.put(:data, tarball_data)

      assert {:ok, result} = Installer.install(config)
      assert File.exists?(result[:binary])
      assert File.read!(result[:binary]) =~ "fake pagefind binary"
    end
  end
end
