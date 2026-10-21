# Get system name (eg x86_64-linux)

system := `nix eval --impure --raw --expr builtins.currentSystem`

# Show available recipes
default:
    @just --list --unsorted

## Building and running

# Build the server executable (hydra-pleco)
build *args:
    nix build {{ args }} ".#hydra-pleco-server:exe:hydra-pleco"

# Build the CLI executable (pleco)
build-cli *args:
    nix build {{ args }} ".#hydra-pleco-cli:exe:pleco"

# Run the server (`just run -- --help`)
run *args:
    nix run ".#hydra-pleco-server:exe:hydra-pleco" -- {{ args }}

# Run the CLI (`just cli -- --help`)
cli *args:
    nix run ".#hydra-pleco-cli:exe:pleco" -- {{ args }}

# Build release artifacts
dist *args:
    nix build \
      {{ args }} \
      ".#x86_64-linux-static-dist"

## Checks

# Run the static analyzers (statix, deadnix, hlint)
lint *args:
    nix build \
      {{ args }} \
      ".#checks.{{ system }}.statix" \
      ".#checks.{{ system }}.deadnix" \
      ".#checks.{{ system }}.hlint"

# Format the source tree in place
fmt *args:
    nix fmt {{ args }}

# Check formatting without writing changes
fmt-check *args:
    nix build {{ args }} ".#checks.{{ system }}.treefmt"

# Run the test suites
test *args:
    nix build \
      {{ args }} \
      ".#checks.{{ system }}.hydra-pleco-api:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-server:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-server:test:db-tests" \
      ".#checks.{{ system }}.hydra-pleco-cli:test:tests"

# Run basic checks
check-light *args:
    nix build \
      {{ args }} \
      ".#checks.{{ system }}.statix" \
      ".#checks.{{ system }}.deadnix" \
      ".#checks.{{ system }}.hlint" \
      ".#checks.{{ system }}.treefmt" \
      ".#checks.{{ system }}.hydra-pleco-api:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-server:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-server:test:db-tests" \
      ".#checks.{{ system }}.hydra-pleco-cli:test:tests"

# Run the full flake check (every check, all systems)
check-full *args:
    nix flake check {{ args }}

## Local tooling

# Run a local Hoogle server
[group('tools')]
hoogle *args=("--port 8000"):
    hoogle server --local {{ args }}

# Build all subprojects
[group('cabal')]
cabal-build *args:
    cabal build all {{ args }}

# Run the server executable (`just cabal-run -- --help`)
[group('cabal')]
cabal-run *args:
    cabal run hydra-pleco-server:exe:hydra-pleco -- {{ args }}

# Run the CLI (`just cabal-cli -- --help`)
[group('cabal')]
cabal-cli *args:
    cabal run hydra-pleco-cli:exe:pleco -- {{ args }}

# Run the database test suite against an ephemeral database
[group('cabal')]
cabal-test-db *args:
    just cabal-test hydra-pleco-server:test:db-tests {{ args }}

# Run the test suite(s)
[group('cabal')]
cabal-test target='all' *args:
    #!/usr/bin/env bash
    set -xeuo pipefail
    pgconn=$(pg_tmp -t | sed -n 's/[^@]*@\([^:]*\):\([^/]*\).*/host=\1 port=\2/p')
    export PLECO_TEST_DATABASE_URL="$pgconn dbname=test"
    export PLECO_TEST_HYDRA_SCHEMA=$(nix build --no-link --print-out-paths ".#hydra-schema")
    cabal test {{ target }} {{ args }}
