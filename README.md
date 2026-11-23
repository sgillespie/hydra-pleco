# hydra-pleco

> A standalone server that attaches to Hydra's PostgreSQL and feeds a webhook/query API.

[![CI](https://github.com/sgillespie/hydra-pleco/actions/workflows/ci.yml/badge.svg)](https://github.com/sgillespie/hydra-pleco/actions/workflows/ci.yml)
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`hydra-pleco` reads Hydra's PostgreSQL database directly and exposes a REST query API
and a webhook dispatcher.

## Layout

```
hydra-pleco-api/       Shared Rest API types
hydra-pleco-server/    Rest API server
hydra-pleco-cli/       CLI API client
nix/                   Flake modules (build, checks, dist, formatter, Hydra schema)
justfile               Task runner recipes
flake.nix              Flake entry point
CONTRIBUTING.md        Checks, commits, API/CLI guidelines and conventions
AGENTS.md              Instructions for coding agents
```

## Getting started

Requires [Nix](https://nixos.org/download.html) (and optionally
[direnv](https://direnv.net)).

```
direnv allow      # or: nix develop
```

The dev shell provides `cabal`, `haskell-language-server`, `hoogle`, the linters and
formatters, and PostgreSQL with `ephemeralpg` for the database tests.

## Workflow

Common build tasks can be run with `just`. To view them, run the default recipe:

```
just
```

Before contributing, read [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
