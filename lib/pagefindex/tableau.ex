if Code.ensure_loaded?(Tableau) do
  defmodule Pagefindex.Tableau do
    @moduledoc """
    A Tableau extension that runs [Pagefind](https://pagefind.app) search indexing after
    site generation. This uses `Pagefindex` for its implementation.

    When the Tableau dev server is running, indexing will be debounced to avoid excessive
    runs during rapid file changes.

    ## Configuration

    Most configuration can be defined in `config :pagefindex, :config`, but for
    convenience, all `Pagefindex` configuration may also be configured via `config
    :tableau, Pagefindex.Tableau`.

    ```elixir
    config :tableau, Pagefindex.Tableau,
      enabled: true,
      command: :auto,
      args: [],
      debounce_ms: 2000,
      on_error: :warn
    ```

    - `:enabled` (default `false`): Enable or disable the extension

    - `:debounce_ms` (default `2000`): Milliseconds to wait between runs when the
      TableauDevServer is running

    All other configuration options are passed through to `Pagefindex`. See `Pagefindex`
    module documentation for details on `:run_with`, `:version`, `:args`, and `:on_error`
    options.

    ## Manual Indexing

    Your Tableau site can be indexed manually with the `Mix.Tasks.Pagefind` task:

    ```console
    $ mix pagefind
    $ mix pagefind --run-with=bun --site=dist
    ```
    """

    # coveralls-ignore-start

    use Tableau.Extension, key: :pagefindex, priority: 999

    # coveralls-ignore-stop

    require Logger

    @last_run_key {__MODULE__, :last_run}

    @defaults %{enabled: false, debounce_ms: 2000, on_error: :warn}

    @valid_on_error [:fail, :ignore, :warn]

    @impl Tableau.Extension
    def config(config) when is_list(config), do: config(Map.new(config))

    def config(config) do
      config = Map.merge(@defaults, config)

      with :ok <- validate_debounce(config[:debounce_ms]),
           :ok <- validate_on_error(config[:on_error]),
           {:ok, pagefind_config} <- Pagefindex.config(config) do
        {:ok, Map.merge(pagefind_config, Map.take(config, [:enabled, :debounce_ms, :on_error]))}
      end
    end

    @impl Tableau.Extension
    def post_write(token) do
      config = token.extensions.pagefindex.config

      if config.enabled and !debounced?(config.debounce_ms) do
        config
        |> Map.put(:site, token.site.config.out_dir)
        |> Pagefindex.pagefind()
        |> handle_result(config)
      end

      {:ok, token}
    end

    defp handle_result({:ok, output}, _config) do
      Logger.info("[Pagefindex] #{Pagefindex.format_success_message(output)}")
    end

    defp handle_result({:error, {_, _, _, _} = result}, config) do
      case config.on_error do
        :fail ->
          message = Pagefindex.format_error_message(result)
          handle_fail_error(message)

        :warn ->
          Logger.warning(Pagefindex.format_error_message(result))

        :ignore ->
          :ok
      end
    end

    defp handle_fail_error(message) do
      if Application.get_env(:tableau, :server) do
        Logger.error(message)
      else
        raise message
      end
    end

    defp debounced?(debounce_ms) do
      now = System.system_time(:millisecond)
      last_run = :persistent_term.get(@last_run_key, 0)

      if last_run == 0 or now - last_run >= debounce_ms do
        :persistent_term.put(@last_run_key, now)
        false
      else
        true
      end
    end

    defp validate_debounce(ms) when is_integer(ms) and ms >= 0, do: :ok

    defp validate_debounce(other) do
      {:error, "invalid :debounce_ms value #{inspect(other)}, expected non-negative integer"}
    end

    defp validate_on_error(val) when val in @valid_on_error, do: :ok

    defp validate_on_error(other) do
      {:error, "invalid :on_error value #{inspect(other)}, expected one of #{inspect(@valid_on_error)}"}
    end
  end
end
