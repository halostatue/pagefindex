# Pagefindex Changelog

## 1.0.4 / 2026-05-13

- Fixed a typo found by [@christhekeele][christhekeele] and originally fixed in
  [#9][pr-9].

## 1.0.3 / 2026-03-02

- Fixed `run_with: :auto` to ensure that `bunx`, `pnpx`, or `npx` exist before
  trying to use a detected package manager. This improves execution in a Docker
  or CI context.

- Fall back to local installation if no usable package manager is found or a
  global installation is not found.

- Fixed a bug with local installation on the use of `:latest`.

## 1.0.2 / 2026-02-24

- Fixed an issue with local installation.
- Fixed a documentation issue with the Tableau extension and the mix task.
- Fixed latest version resolution with the mix task.

## 1.0.1 / 2026-01-26

- Added [usage rules](./usage-rules.md) for use with [`usage_rules`][urules].

  The usage rules were built with the assistance of [Kiro][kiro].

## 1.0.0 / 2025-12-30

- Initial release.

[pr-9]: https://github.com/halostatue/pagefindex/pull/9
[christhekeele]: https://github.com/christhekeele
[kiro]: https://kiro.dev
[urules]: https://github.com/ash-project/usage_rules
