# Get system name (eg x86_64-linux)

system := `nix eval --impure --raw --expr builtins.currentSystem`

# Show available recipes
default:
    @just --list --unsorted

## Building and running

# Build the server executable (hydra-pleco)
build:
    nix build ".#hydra-pleco-server:exe:hydra-pleco"

# Build the CLI executable (pleco)
build-cli:
    nix build ".#hydra-pleco-cli:exe:pleco"

# Run the server (`just run -- --help`)
run *args:
    nix run ".#hydra-pleco-server:exe:hydra-pleco" -- {{ args }}

# Run the CLI (`just cli -- --help`)
cli *args:
    nix run ".#hydra-pleco-cli:exe:pleco" -- {{ args }}

# Build release artifacts
dist:
    nix build \
      ".#x86_64-linux-static-dist" \
      ".#x86_64-windows-dist"

## Checks

# Run the static analyzers (statix, deadnix, hlint)
lint:
    nix build \
      ".#checks.{{ system }}.statix" \
      ".#checks.{{ system }}.deadnix" \
      ".#checks.{{ system }}.hlint"

# Format the source tree in place
fmt:
    nix fmt

# Check formatting without writing changes
fmt-check:
    nix build ".#checks.{{ system }}.treefmt"

# Run the test suites
test:
    nix build \
      ".#checks.{{ system }}.hydra-pleco-api:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-server:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-cli:test:tests"

# Run basic checks
check-light:
    nix build \
      ".#checks.{{ system }}.statix" \
      ".#checks.{{ system }}.deadnix" \
      ".#checks.{{ system }}.hlint" \
      ".#checks.{{ system }}.treefmt" \
      ".#checks.{{ system }}.hydra-pleco-api:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-server:test:tests" \
      ".#checks.{{ system }}.hydra-pleco-cli:test:tests"

# Run the full flake check (every check, all systems)
check-full:
    nix flake check
