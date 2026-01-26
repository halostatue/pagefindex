# Pagefindex Usage Rules

Pagefindex runs [Pagefind](https://pagefind.app) search indexing for static
sites. Works as a Tableau extension or standalone via Mix task.

## Core Principles

1. **Automatic runtime detection** - Detects JavaScript package managers (`bun`,
   `pnpm`, `npm`) or uses global/local Pagefind
2. **Flexible configuration** - Configure via application config or runtime
   options
3. **Version management** - Specify exact versions or use `:latest`
4. **Tableau integration** - Seamless integration with Tableau static site
   generator

## Usage Modes

### 1. Tableau Extension

Automatic indexing after Tableau builds your site.

```elixir
# config/config.exs
config :tableau, Pagefindex.Tableau,
  enabled: true,
  site: "_site",
  run_with: :auto,
  debounce_ms: 2000,
  on_error: :warn
```

Configuration options:

- `:enabled` (default `false`) - Enable/disable the extension
- `:debounce_ms` (default `2000`) - Milliseconds between runs during dev server
- `:on_error` - Error handling: `:fail`, `:warn` (default), or `:ignore`
- All `Pagefindex` options (`:site`, `:run_with`, `:version`, `:args`)

Alternative: Configure via `:pagefindex` instead:

```elixir
config :tableau, Pagefindex.Tableau,
  enabled: true,
  debounce_ms: 2000

config :pagefindex, :config,
  site: "_site",
  run_with: :auto
```

### 2. Mix Task

Manual indexing via command line.

```bash
# Use default configuration
mix pagefind

# Specify site directory
mix pagefind --site=dist

# Force specific runtime
mix pagefind --run-with=bun

# Use specific version
mix pagefind --use-version=1.4.0

# Check version
mix pagefind --version
```

All configuration can be overridden via flags:

```bash
mix pagefind --site=_site --run-with=pnpm --use-version=1.4.0
```

### 3. Programmatic API

For custom integrations or build tools.

```elixir
# Create config and run
config = Pagefindex.config(site: "_site", run_with: :auto)

case Pagefindex.pagefind(config) do
  {:ok, output} -> IO.puts("Success: #{output}")
  {:error, details} -> IO.puts("Error: #{inspect(details)}")
end
```

Check version:

```elixir
config = Pagefindex.config(run_with: :global)

case Pagefindex.pagefind_version(config) do
  {:ok, version} -> IO.puts("Pagefind version: #{version}")
  {:error, reason} -> IO.puts("Error: #{reason}")
end
```

## Decision Guide: When to Use What

### Choose Your Runtime Mode

**Use `:auto` (default) when:**

- You want automatic detection based on JavaScript package manager lock files
- Project uses standard JavaScript package managers
- You want fallback to a global or local installation

**Use `:bun`, `:pnpm`, or `:npm` when:**

- You want to force a specific JavaScript package manager
- Multiple lock files exist and you need explicit control
- Examples: `run_with: :bun`, `run_with: :pnpm`, `run_with: :npm`

**Use `:global` when:**

- Pagefind is installed globally on the system
- You want to use the system-wide installation
- No JavaScript runtime needed

**Use `:local` when:**

- You want Pagefindex to download and manage Pagefind
- No JavaScript runtime available
- Consistent version across environments

**Use `{:command, args}` when:**

- Custom build tool integration (`mise`, `just`, `make`, etc.)
- Non-standard Pagefind execution
- Example: `{:command, ["mise", "run", "pagefind"]}`

### Choose Your Version Strategy

**Use `:latest` (default) when:**

- You want the newest Pagefind features
- Version compatibility isn't critical
- Rapid iteration during development

**Use exact version (e.g., `"1.4.0"`) when:**

- Production deployments requiring stability
- Specific feature requirements
- Reproducible builds

**Note:** Version validation checks are run against `:global` Pagefind versions.

## Common Configuration Patterns

### Force Specific Package Manager

```elixir
# Use Bun exclusively
config :pagefindex, :config,
  site: "dist",
  run_with: :bun,
  version: "1.4.0"
```

### Custom Command Integration

```elixir
# Using mise task runner
config :pagefindex, :config,
  site: "_site",
  run_with: {:command, ["mise", "run", "pagefind"]}
```

### Local Installation

```elixir
# Download and use local binary
config :pagefindex, :config,
  site: "_site",
  run_with: :local,
  version: "1.4.0"
```

### Additional Arguments

```elixir
config :pagefindex, :config,
  site: "_site",
  args: [
    "--verbose",
    "--force-language", "en",
    "--exclude-selectors", ".no-index"
  ]
```

## Configuration Options

### Required

- `:site` - Path to the site directory to index (e.g., `"_site"`, `"dist"`)

### Optional

- `:run_with` - Runtime mode (default: `:auto`)
  - `:auto` - Auto-detect based on JavaScript lock files
  - `:bun` - Use `bunx pagefind`
  - `:pnpm` - Use `pnpx pagefind`
  - `:npm` - Use `npx pagefind`
  - `:global` - Use system `pagefind`
  - `:local` - Download and use local binary
  - `{:command, args}` - Custom command list

- `:version` - Version specification (default: `:latest`)
  - `:latest` - Use latest version
  - `"1.4.0"` - Exact version (validates exact match in `:global` mode)

- `:args` - Additional Pagefind arguments (default: `[]`)
  - Any `--site` or `-s` flags are automatically removed
  - All other arguments passed through to Pagefind

### Tableau Extension Only

- `:enabled` (default `false`) - Enable/disable the extension
- `:debounce_ms` (default `2000`) - Milliseconds between runs during dev server
- `:on_error` - Error handling: `:fail`, `:warn` (default), or `:ignore`

## Auto-Detection Logic

When `:run_with` is `:auto`, Pagefindex checks in order:

1. `bun.lockb` exists → Use `:bun`
2. `pnpm-lock.yaml` exists → Use `:pnpm`
3. `package-lock.json` exists → Use `:npm`
4. `pagefind` in `$PATH` → Use `:global`
5. Otherwise → Use `:local` (download and install)

## Version Validation

When using `:global` mode with a version string:

- Pagefindex validates the installed version matches exactly
- Different major versions produce errors
- Older versions produce errors
- Newer versions produce warnings
- Use `validate: false` option to skip validation

## Common Gotchas

1. **Site argument conflicts** - Any `--site` or `-s` flags in `:args` are
   automatically removed to prevent conflicts with the `:site` configuration.

2. **Custom command args** - When using `{:command, args}`, the args list should
   include the full command. The `:site` and `:args` config are still appended.

3. **Version format** - Version must be a string (`"1.4.0"`) or `:latest`.
   Complex requirements like `"~> 1.4"` are not supported.

4. **Local installation** - First run with `:local` downloads Pagefind, which
   may take time. Subsequent runs use the cached binary.

5. **Global version mismatch** - If `:global` mode finds a different version
   than specified, it errors (different major or older) or warns (newer). Use
   `:auto` for automatic fallback.

6. **Lock file priority** - With multiple lock files, `:auto` mode picks the
   first match (`bun > pnpm > npm`). Use explicit mode to override.

## Error Handling

Pagefindex returns `{:ok, output}` on success or `{:error, details}` on failure.

```elixir
case Pagefindex.pagefind(config) do
  {:ok, output} -> 
    Logger.info("Pagefind indexing completed")
  
  {:error, {command, args, output, exit_code}} ->
    Logger.error("Pagefind failed with exit code #{exit_code}")
end
```

## Performance Tips

1. **Use local mode in CI** - Consistent versions and no npm overhead
2. **Cache local binaries** - Cache the Pagefindex installation directory
3. **Minimize args** - Only pass necessary Pagefind arguments
4. **Version pinning** - Use exact versions in production for reproducibility

## Resources

- **[Pagefind Documentation](https://pagefind.app)** - Official Pagefind docs
- **[Hex Package](https://hex.pm/packages/pagefindex)** - Package on Hex.pm
- **[HexDocs](https://hexdocs.pm/pagefindex)** - Complete API documentation
- **[GitHub Repository](https://github.com/halostatue/pagefindex)** - Source
  code
- **[Tableau](https://hex.pm/packages/tableau)** - Static site generator
