# AGENTS.md

Conventions for AI coding agents (and humans) working in `hydra-pleco`. Everything here
was derived from the existing code; when this file and the code disagree, the code wins
and this file must be fixed.

## Maintaining this file

This file exists so changes match the maintainer's style without correction. **If a
reviewer corrects anything about structure, naming, or style that this file did not
cover, or covered wrongly, update this file in the same change.** Add the rule where it
belongs, phrased as an instruction, with a real example from the codebase. Remove rules
the code no longer follows.

______________________________________________________________________

## 1. Repository layout

```
hydra-pleco/
├── cabal.project              # package list, index-state pin, constraints
├── flake.nix / flake.lock     # Nix entry point (flake-parts)
├── nix/                       # one flake-parts module per concern
│   ├── haskell-project.nix    #   haskell.nix project + dev shell
│   ├── hydra-schema.nix       #   Hydra's hydra.sql, used by DB tests
│   ├── distribution.nix       #   static release archives
│   ├── checks.nix             #   statix / deadnix / hlint checks
│   └── formatter.nix          #   treefmt formatters
├── justfile                   # all task recipes
├── fourmolu.yaml  .hlint.yaml # formatter / linter config
├── hydra-pleco-api/           # shared Servant API types + OpenAPI (no server/client code)
├── hydra-pleco-server/        # REST server + webhook dispatcher (exe: hydra-pleco)
└── hydra-pleco-cli/           # client library + CLI (exe: pleco)
```

### 1.1 Package layout (identical shape in every package)

```
hydra-pleco-<pkg>/
├── hydra-pleco-<pkg>.cabal
├── src/Hydra/Pleco/...        # library
├── app/Main.hs                # executable (server, cli only) — thin: options + call library
├── testlib/Hydra/Pleco/...    # public internal library: Hedgehog generators + fixtures
├── test/                      # `tests` suite: pure + in-process HTTP tests
│   ├── Main.hs
│   └── Hydra/Pleco/...Spec.hs
└── db-test/                   # (server only) `db-tests` suite needing PostgreSQL
    ├── Main.hs
    ├── data/seed.sql
    └── Hydra/Pleco/...Spec.hs
```

- Golden files live at `<pkg>/.golden/<name>/golden` (e.g.
  `hydra-pleco-api/.golden/openapi.json/golden`) and are listed in `extra-source-files`.
  The generated `actual` file is gitignored; accept a change by copying `actual` to `golden`.
- Never put API types in server or cli. Never put server logic in api.
- Dependency direction: `cli → api`, `server → api`, and server *tests* may use `cli`
  (the real client is used to exercise the server).

### 1.2 Module hierarchy

Root namespace is `Hydra.Pleco`, then the package role:

| Package | Namespace | Feature modules are… |
|---|---|---|
| api | `Hydra.Pleco.Api.<Resource>` | **singular**: `Api.Project`, `Api.Jobset`, `Api.Eval`, `Api.Event` |
| server | `Hydra.Pleco.Server.<Resources>` | **plural**: `Server.Projects`, `Server.Jobsets`, `Server.Evals` (exception: `Server.Webhook`) |
| cli | `Hydra.Pleco.Client[.<Thing>]` | `Client`, `Client.EchoServer` |

Server structure per resource:

```
Server/<Resources>.hs        # Servant handlers only
Server/<Resources>/DB.hs     # pure conversions: DB row type <-> API type (from…/to…)
Server/DB.hs                 # pool/session helpers; re-exports Server.DB.Hydra
Server/DB/Hydra.hs           # Rel8 table types, TableSchemas, and ALL query Statements
Server/Monad.hs              # PlecoServerT / PlecoServerEnv
Server/Error.hs              # PlecoServerError
Server.hs                    # wires all handlers into HydraApi, runs Warp
```

- The umbrella module (`Hydra.Pleco.Api`, `Hydra.Pleco.Server`, `Hydra.Pleco.Client`)
  re-exports what consumers need. Route records (`HydraApi`, `ProjectsApi`, …) live in
  `Hydra.Pleco.Api` itself, not in the per-resource modules.
- Queries are not spread across `<Resources>/DB.hs`; they all live in `Server/DB/Hydra.hs`.

### 1.3 Tests and testlib

- Spec module name = module under test + `Spec`, same directory path:
  `Server/DB/Hydra.hs` → `test/Hydra/Pleco/Server/DB/HydraSpec.hs`.
- Every spec module is `module X.YSpec (spec) where` with `spec :: Spec`
  (db-tests: `spec :: SpecWith (Text, Pool)`).
- `Main.hs` imports each spec `qualified as <Name>Spec` and calls `<Name>Spec.spec`
  inside `hspec $ do`.
- Generators live in `testlib/Hydra/Pleco/<Pkg>/Gen.hs` (`Hydra.Pleco.Api.Gen`,
  `Hydra.Pleco.Server.Gen`, `Hydra.Pleco.Client.Gen`). Other fixtures sit next to it
  (`Server/TestApp.hs`, `Server/TestDb.hs`).
- Pure / property tests go in `test/`. Anything needing PostgreSQL goes in `db-test/`.

### 1.4 Adding a new resource (checklist, using "Build" as the example)

1. `hydra-pleco-api/src/Hydra/Pleco/Api/Build.hs`: `Build`, `BuildId`, JSON + `ToSchema` instances.
2. `Hydra.Pleco.Api`: add `BuildsApi mode` route record, a field on `HydraApi`, re-exports.
3. `Server/DB/Hydra.hs`: `data Build f` Rel8 table, `buildSchema`, query statements.
4. `Server/Builds/DB.hs`: `fromBuild` / `toBuild`.
5. `Server/Builds.hs`: `buildsHandler` record + `list…Handler` / `get…Handler`.
6. `Server.hs`: add the field to `apiServer`.
7. `Client.hs`: `listBuilds` / `getBuild`, plus re-exports; `cli/app/Main.hs`: subcommand.
8. Generators in each `Gen.hs`; specs in `test/` and/or `db-test/`.
9. Add every new module to the right `.cabal` stanza (`exposed-modules` / `other-modules`).
10. Run `just fmt`, regenerate the OpenAPI golden file, then run `just check-light`.

______________________________________________________________________

## 2. Naming conventions

### 2.1 Record fields: short type prefix

There is no `DuplicateRecordFields`, so every field starts with a short (2–4 letter)
prefix derived from its type name. For an existing type, read its definition and reuse its
prefix. Never guess. For a new type, pick a prefix in one of these styles:

- **Truncation**: `Project` → `prjDisplayName`, `Subscription` → `subUrl`
- **Initials**: `PlecoServerEnv` → `pseDbPool`, `JobsetEvent` → `jeEventType`
- **Route records** add `a` to the resource prefix: `ProjectsApi` → `prjaList`, `JobsetsApi` → `jsaEvals`

The API and DB versions of a resource may use **different** prefixes: `Api.Eval` uses
`ev` (`evNumBuilds`) while the DB row `JobsetEval` uses `jse` (`jseNumBuilds`). Check
which layer you are in.

Route-record fields use the verbs `List`, `Get`, or a sub-resource name: `prjaList`,
`prjaGet`, `prjaJobsets`.

Field names are full camelCase words with these abbreviations: `Num` (count),
`DynCmd` / `DynRunCmd`, `Decl`, `Db`, `Msg`.

### 2.2 Types and constructors

- Identifiers are newtypes named `<Thing>Id`/`<Thing>Name` with accessor `un<Type>`:
  `newtype JobsetId = JobsetId {unJobsetId :: Int}`.
- API and DB layers each have their own types with the **same name** (`Api.Jobset` vs
  `Db.Jobset`, both have `JobsetId`). Tell them apart by qualified import, not by renaming.
- Enum constructors are prefixed with the type's initials:
  `JobsetState` → `JssEnabled`, `JssOneShot`; `JobsetType` → `JstFlake`, `JstLegacy`.
- Constructors that name a domain event spell it out: `EvalAdded`, `HydraEvalStarted`.
- Error types: `Pleco<Role>Error` with role-prefixed constructors:
  `ServerDbConnectionError`, `ServerParsingError`; `PlecoClientError`, `PlecoCmdError`.
- App monad and env: `Pleco<Role>T` / `Pleco<Role>`, `Pleco<Role>Env`.
- Route records: `<Resources>Api mode` (plural), e.g. `ProjectsApi`, `JobsetsApi`.
- CLI command types: `Command` with `Cmd<Name>` constructors; nested sum types
  `<Resources>SubCommand` with `Cmd<Resources><Verb>`: `CmdProjectsList`, `CmdJobsetsView`.

### 2.3 Functions

| Purpose | Pattern | Examples |
|---|---|---|
| Build an environment/value | `mk…` | `mkPlecoServerEnv`, `mkPlecoClientEnv`, `mkPayload` |
| Run a monad / action | `run…` | `runPlecoServerT`, `runSession`, `runServer` |
| Bracketed resource | `with…` | `withConnectionPool`, `withHydraDb`, `withServer` |
| Acquire / release | `new…` / `release…` | `newConnectionPool`, `releaseConnection` |
| Layer conversion | `from<Type>` (DB→API) / `to<Type>` (API→DB) | `fromJobset`, `toProject` |
| Text ↔ value | `parse…` / `render…` | `parseJobsetSpec`, `renderHydraNotification` |
| Servant route record handler | `<resources>Handler` | `projectsHandler`, `webhooksHandler` |
| Individual endpoint handler | `<verb><Thing>Handler` | `listJobsetsHandler`, `getEvalHandler` |
| Client calls | `get<Thing>` / `list<Things>` / `find<Thing>` | `getProject`, `listEvals`, `findJobset` |
| Rel8 table schema | `<thing>Schema` | `jobsetEvalSchema` |
| Rel8 queries (`Statement`) | `each<Thing>`, `<thing>ById`, `<things>By<Field>[And<Field>]` | `eachProject`, `jobsetById`, `jobsetsByProjectAndName` |
| Hedgehog generator | lowercase type name | `project`, `jobsetId`, `hydraNotification` |
| CLI parsers | `parse<X>Cmd`, `parse<X>Opt`, `<x>CmdInfo`; runners `run<X>` | `parseEchoCmd`, `parsePort`, `runEvals` |

- Use a trailing prime for a local that shadows or derives from another name:
  `state'`, `type'`, `manager'`, `logEnv'`, `init'`, `readJobsetId'`.
- Bind a variant of a function with a prime when a helper wraps it: `runClient` / `runClient'`.

### 2.4 Qualified import aliases

Use the module's last component, or these established short aliases:

| Module | Alias |
|---|---|
| `Hydra.Pleco.Api` | `Api` |
| `Hydra.Pleco.Server.DB.Hydra` (in conversion modules) | `Db` |
| `Hydra.Pleco.Server.DB` (in handler modules) | `DB` |
| `Hydra.Pleco.Api.Gen` (from server tests) | `ApiGen` |
| `<pkg>.Gen` inside that package's tests | `Gen` |
| `Options.Applicative` | `Opt` |
| `Data.HashMap.Strict.InsOrd.Compat` | `InsOrd` |
| `Data.Aeson.Encode.Pretty` | `Aeson` (re-export) / `Pretty` / `AesonPretty` |
| `Network.Wai.Handler.Warp` | `Warp` |
| `Katip.Wai` | `KatipWai` |
| `Hasql.Pool`, `Hasql.Pool.Config` | `Pool` |
| others | `Aeson`, `Text`, `Katip`, `Rel8`, `Servant`, `OpenApi`, `Session`, `Connection`, `Async`, `Exception` |

### 2.5 Wire and database names

- JSON keys and OpenAPI properties are **snake_case**: `"check_interval"`,
  `"enable_email_notification"`. The Haskell field name and JSON key don't have to match
  (`jsEnableDynRunCmd` ↔ `"enable_dynamic_runcommand_hooks"`).
- DB column names are Hydra's own (mostly lowercase concatenated: `"nixexprinput"`,
  `"keepnr"`). Never rename them; map them in the `…Schema` record.
- URL path segments are lowercase plural (`"projects"`, `"jobsets"`, `"evals"`), and captures are `"id"`.
- CLI subcommands are singular nouns + verbs: `pleco project list`, `pleco jobset view PROJECT:NAME`.

______________________________________________________________________

## 3. Code style

Formatting is enforced by fourmolu (`fourmolu.yaml`). **Always run `just fmt` (or
`nix fmt`) before finishing.** Don't hand-format against it.

- **Every module has an explicit export list** (enforced by `-Wmissing-export-lists`).
  Use `(..)` for types whose constructors/fields are part of the API. Large umbrella
  modules group exports with `-- * Section` headings (see `Hydra.Pleco.Client`).
- **Import groups**: project modules (`Hydra.Pleco.*`) first, blank line, then
  third-party modules, each group alphabetical. Use postfix `qualified`
  (`import Data.Text qualified as Text`). Often a module is imported twice: once for
  types/operators unqualified, once qualified for functions.
- **Prelude is relude** (mixin in every `.cabal`). Don't import `Data.Text (Text)`,
  `Control.Monad.Reader`, etc. relude already exports them. Prefer relude names:
  `pass`, `one`, `toText`/`toString`, `readFileBS`, `usingReaderT`, `putLBSLn`. hlint
  enforces many of these.
- **Deriving**: always give a strategy: `deriving stock (Eq, Show, Generic)`,
  `deriving newtype (ToJSON, FromHttpApiData, …)`, `deriving anyclass (Rel8able)`.
- **Records**: construct with explicit field names, one per line; destructure with
  `RecordWildCards` (`Jobset {..}`) or `NamedFieldPuns` (`PlecoServerEnv {pseDbPool}`).
- **JSON**: write `ToJSON` (both `toJSON` and `toEncoding`), `FromJSON` and `ToSchema`
  by hand. Don't use Generic-derived JSON. `ToSchema` uses optics with
  `OverloadedLabels` (`& #properties .~ …`).
- **Servant**: `NamedRoutes` records (`data XApi mode = XApi { … :: mode :- … }`). The
  server builds the same record with handlers; the client uses `genericClient` and `//`/`/:`.
- **Handlers** run in `PlecoServerT Handler`, read env with `asks pse…`, call
  `runSession pool $ statement () <query>`, then map through `from<Type>`.
- **Errors**: throw with `throwIO` (UnliftIO), turning `Either` into exceptions with `either throwIO pure`.
  Add new cases to `PlecoServerError` rather than new exception types.
- **Resources**: `bracket` / `bracket_` / `with…` helpers, never manual acquire/release.
- **Logging**: Katip, `Katip.logFM <Severity> "…"`, namespaces via `katipAddNamespace`.
- `where` clauses for local helpers. Give type signatures to non-trivial `where` bindings.
- Haddock: `-- |` on types and non-obvious functions, kept short. Comments explain *why*.
- TODOs are owned: `-- TODO[sgillespie]: …`.
- Strict fields (`!`) only in CLI/server option records.

## 4. Tests

- hspec + hedgehog via `hspec-hedgehog`.
- `describe "<TypeOrModule>"` → nested `describe "<function>"` → `it "<lowercase
  present-tense behaviour>"`: `it "sets hidden to not visible"`.
- Standard property set for API types: round-trips through Aeson, `toJSON` and
  `toEncoding` match, conforms to its OpenApi schema (`validateToJSON`).
- Conversion modules get a `tripping` round-trip test plus one test per non-trivial field mapping.
- Server HTTP tests start the real app on a Warp test port and call it through
  `Hydra.Pleco.Client`. Don't hand-build HTTP requests unless testing headers/status.

## 5. Tooling and workflow

| Task | Command |
|---|---|
| Format everything | `just fmt` |
| Lint (hlint, statix, deadnix) | `just lint` |
| Fast dev build / tests (in dev shell) | `just cabal-build`, `just cabal-test`, `just cabal-test-db` |
| What CI runs | `just build`, `just check-light`, `just check-full` |

- `.cabal` files are formatted by cabal-gild: module and dependency lists are alphabetical,
  one per line, with trailing commas.
- Nix files: alejandra formatting. A new concern gets its own `nix/<concern>.nix`
  flake-parts module, imported from `flake.nix` with a one-line comment.
- New `just` recipes get a `# Description` comment line, and cabal-based ones go in `[group('cabal')]`.
- Commit messages: imperative, sentence case, no type prefix, no trailing period
  (`Add endpoints for Jobset`, `Refactor jobset lookups from client`). Formatting-only
  commits are titled `` `just fmt` `` or `` `nix fmt` ``. Golden updates get their own commit.

## 6. Known inconsistencies (don't copy these, and don't "fix" them unasked)

- `test/…/Server/ProjectSpec.hs` (singular) vs `db-test/…/Server/ProjectsSpec.hs`
  (plural). Name new specs after the module under test.
- A few files put a `Hydra.Pleco.*` import in the third-party group (`Server.hs`,
  `Server/Projects.hs`, some specs). New code should follow the grouping rule in §3.
- `DB` vs `Db` alias for the database modules. Follow §2.4.
- CLI parser naming mixes `parse<X>Cmd` and `<x>Opts` (`projectsOpts`). Prefer `parse<X>Cmd`.
- `tested-with: ghc ==9.10.*` in the `.cabal` files, but Nix builds with GHC 9.12 (`ghc912`).
