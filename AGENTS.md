# AGENTS.md

Instructions for coding agents. [README.md](README.md) covers layout and setup, and
[CONTRIBUTING.md](CONTRIBUTING.md) covers rules and conventions.

## Before Making a Change

- Before changing an endpoint, read
  [Rest API Guidelines](CONTRIBUTING.md#rest-api-guidelines) and
  [Errors](CONTRIBUTING.md#errors).
- Before changing a CLI command or its output, read
  [CLI Guidelines](CONTRIBUTING.md#cli-guidelines).
- Before adding a module, an import or a test, read
  [Conventions](CONTRIBUTING.md#conventions).
- Before committing, read [Commits](CONTRIBUTING.md#commits).

## Verification

Run everything inside the dev shell (`nix develop`, or direnv).

| When                         | Command                               |
| ---------------------------- | ------------------------------------- |
| While iterating              | `just cabal-build`, `just cabal-test` |
| After changing SQL or `DB/`  | `just cabal-test-db`                  |
| After any edit               | `just fmt`                            |
| Before reporting a task done | `just check-light`                    |

## Guidelines

- Don't hand-format code or Markdown. Run `just fmt`, since treefmt owns formatting.
- Don't edit `data/**/golden` files by hand. Delete the `golden` file, rerun the suite,
  and review the regenerated file.
- Don't edit the OpenAPI spec (`hydra-pleco-api/data/openapi.json/golden`). Change the
  Servant API types, then regenerate it as above.
- Don't link to untracked files (check with `git status --ignored`) from tracked files.
  Other clones won't have them. Cite tracked paths or external URLs instead.
