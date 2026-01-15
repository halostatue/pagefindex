# Pagefindex

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/halostatue/pagefindex>
- issues :: <https://github.com/halostatue/pagefindex/issues>

Runs [Pagefind](https://pagefind.app) search indexing for static sites. Works as
a [Tableau][tableau] extension or standalone via Mix task.

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
config :tableau, Pagefindex.Tableau,
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

The extension automatically detects your package manager (`bun`, `pnpm`, `npm`)
and runs the appropriate Pagefind command. See the [module documentation][docs]
for configuration options.

## Semantic Versioning

Pagefindex follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/pagefindex
[hexpm]: https://hex.pm/packages/pagefindex
[licence]: https://github.com/halostatue/pagefindex/blob/main/LICENCE.md
[mdex]: https://hex.pm/packages/mdex
[posts]: https://hexdocs.pm/tableau/Tableau.PostExtension.html
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/halostatue/pagefindex?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/pagefindex?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/pagefindex?style=for-the-badge&label=licence "Apache 2.0"
[tableau]: https://hex.pm/packages/tableau
