# hydra-pleco

> A standalone server that attaches to Hydra's PostgreSQL and feeds a webhook/query API.

[![CI](https://github.com/sgillespie/hydra-ng/actions/workflows/ci.yml/badge.svg)](https://github.com/sgillespie/hydra-ng/actions/workflows/ci.yml)
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`hydra-pleco` reads Hydra's PostgreSQL database directly and exposes a REST query API and a
webhook dispatcher.

## Layout

```
hydra-pleco-api/       Shared Rest API types
hydra-pleco-server/    Rest API server
hydra-pleco-cli/       CLI API client
nix/                   Flake modules (build, checks, dist, formatter)
justfile               Task runner recipes
flake.nix              Flake entry point
```

## Getting started

Requires [Nix](https://nixos.org/download.html) (and optionally
[direnv](https://direnv.net)).

```
direnv allow      # or: nix develop
```

The dev shell provides `cabal`, `haskell-language-server`, `hoogle`, and linters.

## Workflow

Common build tasks can be run with `just`. To view them, run the default recipe:

```
just

Available recipes:
    default     # Show available recipes
    build       # Build the server executable (hydra-pleco)
    build-cli   # Build the CLI executable (pleco)
    run *args   # Run the server (`just run -- --help`)
    cli *args   # Run the CLI (`just cli -- --help`)
    dist        # Build release artifacts
    lint        # Run the static analyzers (statix, deadnix, hlint)
    fmt         # Format the source tree in place
    fmt-check   # Check formatting without writing changes
    test        # Run the test suites
    check-light # Run basic checks
    check-full  # Run the full flake check (every check, all systems)
```

## License

[MIT](LICENSE)
