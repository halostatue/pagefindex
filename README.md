# Pagefindex

[![Hex Version](https://img.shields.io/hexpm/v/pagefindex?style=for-the-badge "Hex Version")](https://hex.pm/packages/mdex_custom_heading_id)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs")](https://hexdocs.pm/pagefindex)
[![Apache 2.0](https://img.shields.io/hexpm/l/pagefindex?style=for-the-badge&label=licence "Apache 2.0")](https://github.com/halostatue/mdex_custom_heading_id/blob/main/LICENCE.md)
![Coverage](https://img.shields.io/coverallsCoverage/github/halostatue/pagefindex?style=for-the-badge "Coverage")

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
[tableau]: https://hex.pm/packages/tableau
