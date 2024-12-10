if Code.ensure_loaded?(Tableau) do
  defmodule Pagefindex.TableauTest do
    use ExUnit.Case, async: false

    import ExUnit.CaptureLog

    describe "config/1" do
      test "accepts keyword list config" do
        assert {:ok, config} = Pagefindex.Tableau.config(enabled: true)
        assert config.enabled == true
      end

      test "accepts map config" do
        assert {:ok, config} = Pagefindex.Tableau.config(%{enabled: false})
        assert config.enabled == false
      end

      test "has sensible defaults" do
        assert {:ok, config} = Pagefindex.Tableau.config(%{})
        assert config.enabled == false
        assert config.run_with == :auto
        assert config.version == :latest
        assert config.args == []
        assert config.debounce_ms == 2000
        assert config.on_error == :warn
      end

      test "validates debounce_ms" do
        assert {:ok, config} = Pagefindex.Tableau.config(debounce_ms: 5000)
        assert config.debounce_ms == 5000
      end

      test "accepts zero debounce_ms" do
        assert {:ok, config} = Pagefindex.Tableau.config(debounce_ms: 0)
        assert config.debounce_ms == 0
      end

      test "rejects negative debounce_ms" do
        assert {:error, message} = Pagefindex.Tableau.config(debounce_ms: -100)
        assert message =~ "invalid :debounce_ms value"
      end

      test "rejects non-integer debounce_ms" do
        assert {:error, message} = Pagefindex.Tableau.config(debounce_ms: "fast")
        assert message =~ "invalid :debounce_ms value"
      end

      test "accepts valid on_error values" do
        for val <- [:warn, :fail, :ignore] do
          assert {:ok, config} = Pagefindex.Tableau.config(on_error: val)
          assert config.on_error == val
        end
      end

      test "rejects invalid on_error" do
        assert {:error, message} = Pagefindex.Tableau.config(on_error: :invalid)
        assert message =~ "invalid :on_error value"
      end

      test "passes through pagefind config validation" do
        assert {:error, message} = Pagefindex.Tableau.config(run_with: :invalid, version: :latest)
        assert message =~ "invalid :run_with value"
      end
    end

    describe "post_write/1" do
      setup do
        :persistent_term.erase({Pagefindex.Tableau, :last_run})

        on_exit(fn ->
          Application.delete_env(:pagefindex, :system_impl)
          :persistent_term.erase({Pagefindex.Tableau, :last_run})
        end)

        :ok
      end

      test "skips when disabled" do
        MockSystem.prepare(mode: :global, find: true, status: :error)
        Application.put_env(:pagefindex, :system_impl, MockSystem)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: false,
                run_with: :auto,
                version: :latest,
                args: [],
                debounce_ms: 2000,
                on_error: :warn
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        assert {:ok, ^token} = Pagefindex.Tableau.post_write(token)
      end

      test "runs pagefind when enabled and not debounced" do
        MockSystem.prepare(mode: :global, find: true, status: :ok)
        Application.put_env(:pagefindex, :system_impl, MockSystem)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: true,
                run_with: :auto,
                version: :latest,
                args: [],
                # No debouncing
                debounce_ms: 0,
                on_error: :warn
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        assert capture_log(fn -> assert {:ok, ^token} = Pagefindex.Tableau.post_write(token) end) =~
                 "[info] [Pagefindex] 1 language, 46 pages, 3810 words, and 2 filters"
      end

      test "handles pagefind failure with warn level" do
        MockSystem.prepare(mode: :global, find: true, status: :error)
        Application.put_env(:pagefindex, :system_impl, MockSystem)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: true,
                run_with: :auto,
                version: :latest,
                args: [],
                debounce_ms: 0,
                on_error: :warn
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        assert capture_log(fn -> assert {:ok, ^token} = Pagefindex.Tableau.post_write(token) end) =~
                 "[warning] [Pagefindex] Failed with exit code 1"
      end

      test "handles pagefind failure with ignore level" do
        MockSystem.prepare(mode: :global, find: true, status: :error)
        Application.put_env(:pagefindex, :system_impl, MockSystem)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: true,
                run_with: :auto,
                version: :latest,
                args: [],
                debounce_ms: 0,
                on_error: :ignore
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        log =
          capture_log(fn ->
            assert {:ok, ^token} = Pagefindex.Tableau.post_write(token)
          end)

        # Should not log anything with ignore level
        refute log =~ "[Pagefindex]"
      end

      test "raises error with fail level in non-server mode" do
        MockSystem.prepare(mode: :global, find: true, status: :error)
        Application.put_env(:pagefindex, :system_impl, MockSystem)
        Application.delete_env(:tableau, :server)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: true,
                run_with: :auto,
                version: :latest,
                args: [],
                debounce_ms: 0,
                on_error: :fail
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        try do
          Pagefindex.Tableau.post_write(token)
          flunk("Expected RuntimeError to be raised")
        rescue
          e in RuntimeError ->
            assert e.message =~ "[Pagefindex] Failed with exit code 1"
        end
      end

      test "logs error with fail level in server mode" do
        MockSystem.prepare(mode: :global, find: true, status: :error)
        Application.put_env(:pagefindex, :system_impl, MockSystem)
        Application.put_env(:tableau, :server, true)
        on_exit(fn -> Application.delete_env(:tableau, :server) end)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: true,
                run_with: :auto,
                version: :latest,
                args: [],
                debounce_ms: 0,
                on_error: :fail
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        assert capture_log(fn -> assert {:ok, ^token} = Pagefindex.Tableau.post_write(token) end) =~
                 "[error] [Pagefindex] Failed with exit code 1"
      end

      test "debounces rapid calls" do
        MockSystem.prepare(mode: :global, find: true, status: :ok)
        Application.put_env(:pagefindex, :system_impl, MockSystem)

        token = %{
          extensions: %{
            pagefindex: %{
              config: %{
                enabled: true,
                run_with: :auto,
                version: :latest,
                args: [],
                # 1 second debounce
                debounce_ms: 1000,
                on_error: :warn
              }
            }
          },
          site: %{config: %{out_dir: "_site"}}
        }

        assert capture_log(fn -> assert {:ok, ^token} = Pagefindex.Tableau.post_write(token) end) =~
                 "[info] [Pagefindex] 1 language, 46 pages, 3810 words, and 2 filters"

        assert capture_log(fn -> assert {:ok, ^token} = Pagefindex.Tableau.post_write(token) end) == ""
      end
    end
  end
end
