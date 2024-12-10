# Pagefindex

- code :: <https://github.com/halostatue/pagefindex>
- issues :: <https://github.com/halostatue/pagefindex/issues>

Runs [Pagefind](https://pagefind.app) search indexing for static sites. Works as a Tableau extension or standalone via Mix task.

## Installation

Add `pagefindex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pagefindex, "~> 1.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Usage

### As Tableau Extension

Enable in your Tableau configuration:

```elixir
config :tableau, Pagefindex,
  enabled: true
```

### Manual Indexing

Run the Mix task to index your site:

```console
$ mix pagefind
$ mix pagefind --site=dist
$ mix pagefind --run-with=bun
$ mix pagefind --use-version=1.4.0
$ mix pagefind --version
```

The extension automatically detects your package manager (`bun`, `pnpm`, `npm`) and runs the appropriate Pagefind command. See the [module documentation][docs] for configuration options.

## Semantic Versioning

Pagefindex follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/pagefindex
[semver]: https://semver.org/
