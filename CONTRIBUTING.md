# Contributing to hydra-pleco

Thanks for taking the time to contribute! To set up Hydra and pleco, see the
[README](README.md#getting-started).

## Table of contents

- [Making changes](#making-changes)
  - [Checks](#checks)
  - [Commits](#commits)
- [Rest API Guidelines](#rest-api-guidelines)
- [CLI Guidelines](#cli-guidelines)
- [Conventions](#conventions)
  - [Packages and modules](#packages-and-modules)
  - [Haskell style](#haskell-style)
  - [Errors](#errors)
  - [Tests](#tests)

## Making changes

### Checks

Run `just check-light` before you push. It runs the linters (statix, deadnix, hlint),
formatting checks and all test suites.

| Command            | Runs                                |
| ------------------ | ----------------------------------- |
| `just check-light` | Lint, format check, all test suites |
| `just check-full`  | Every check on all systems          |
| `just lint`        | statix, deadnix, hlint              |
| `just test`        | All test suites                     |
| `just fmt`         | Formats the source tree in place    |
| `just fmt-check`   | Checks formatting without writing   |

For faster iteration, `cabal-*` recipes are available in the dev shell:

- `just cabal-test` runs every suite incrementally. To run one suite, pass its target
  (eg, `just cabal-test hydra-pleco-api:test:tests`).
- `just cabal-test-db` runs integration tests on an isolated, tempoorary database.

### Commits

Do not use Conventional Commits with prefixes such as `feat:` or `fix(cli):`.
**Rationale:** Prefixes take up the valuable space in the short description, and its
structure improves commit logs only when strictly followed.

Follow the [seven rules](https://cbea.ms/git-commit/#seven-rules) of a git commit message:

1. Separate the subject from the body with a blank line.
1. Limit the subject line to 50 characters.
1. Capitalize the subject line.
1. Do not end the subject line with a period.
1. Use the imperative mood in the subject line (eg, `Move handlers into new namespace`).
1. Wrap the body at 72 characters.
1. Use the body to explain what and why, not how.

Write the body so a reviewer can review the change from the commit alone: what changed,
why, and what effect it has. Put issue references at the end of the body
(`Resolves: #123`).

## Rest API Guidelines

API rules are adapted from
[Zalando RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/),
and each rule links to its original. MUST rules are required. SHOULD rules are expected
unless there is a good reason not to follow them.

### MUST

 - Provide API Specifications using OpenAPI ([#101](https://opensource.zalando.com/restful-api-guidelines/#101))
 - Contain API meta information ([#218](https://opensource.zalando.com/restful-api-guidelines/#218))
 - Use semantic versioning ([#116](https://opensource.zalando.com/restful-api-guidelines/#116))
 - Use standard data formats ([#238](https://opensource.zalando.com/restful-api-guidelines/#238))
 - Define a format for number and integer types ([#171](https://opensource.zalando.com/restful-api-guidelines/#171))
 - Use standard formats for date and time properties ([#169](https://opensource.zalando.com/restful-api-guidelines/#169))
 - Pluralize resource names ([#134](https://opensource.zalando.com/restful-api-guidelines/#134))
 - Use URL-friendly resource identifiers ([#228](https://opensource.zalando.com/restful-api-guidelines/#228))
 - Use kebab-case for path segments ([#129](https://opensource.zalando.com/restful-api-guidelines/#129))
 - Keep URLs verb-free ([#141](https://opensource.zalando.com/restful-api-guidelines/#141))
 - Avoid actions — think about resources ([#138](https://opensource.zalando.com/restful-api-guidelines/#138))
 - Use domain-specific resource names ([#142](https://opensource.zalando.com/restful-api-guidelines/#142))
 - Identify resources and sub-resources via path segments ([#143](https://opensource.zalando.com/restful-api-guidelines/#143))
 - Limit number of sub-resource levels ([#147](https://opensource.zalando.com/restful-api-guidelines/#147))
 - Use snake_case (never camelCase) for query parameters ([#130](https://opensource.zalando.com/restful-api-guidelines/#130))
 - Stick to conventional query parameters ([#137](https://opensource.zalando.com/restful-api-guidelines/#137))
 - Use JSON as payload data interchange format ([#167](https://opensource.zalando.com/restful-api-guidelines/#167))
 - Property names must be snake_case (and never camelCase) ([#118](https://opensource.zalando.com/restful-api-guidelines/#118))
 - Pluralize array names ([#120](https://opensource.zalando.com/restful-api-guidelines/#120))
 - Declare enum values using UPPER_SNAKE_CASE string ([#240](https://opensource.zalando.com/restful-api-guidelines/#240))
 - Use same semantics for null and absent properties ([#123](https://opensource.zalando.com/restful-api-guidelines/#123))
 - Not use null for boolean properties ([#122](https://opensource.zalando.com/restful-api-guidelines/#122))
 - Use common field names and semantics ([#174](https://opensource.zalando.com/restful-api-guidelines/#174))
 - Use HTTP methods correctly ([#148](https://opensource.zalando.com/restful-api-guidelines/#148))
 - Fulfill common method properties ([#149](https://opensource.zalando.com/restful-api-guidelines/#149))
 - Define collection format of header and query parameters ([#154](https://opensource.zalando.com/restful-api-guidelines/#154))
 - Document implicit response filtering ([#226](https://opensource.zalando.com/restful-api-guidelines/#226))
 - Use official HTTP status codes ([#243](https://opensource.zalando.com/restful-api-guidelines/#243))
 - Specify success and error responses ([#151](https://opensource.zalando.com/restful-api-guidelines/#151))
 - Use most specific HTTP status codes ([#220](https://opensource.zalando.com/restful-api-guidelines/#220))
 - Support problem JSON ([#176](https://opensource.zalando.com/restful-api-guidelines/#176))
 - Not expose stack traces ([#177](https://opensource.zalando.com/restful-api-guidelines/#177))
 - Use kebab-case with uppercase separate words for HTTP headers ([#132](https://opensource.zalando.com/restful-api-guidelines/#132))
 - Use Content-* headers correctly ([#178](https://opensource.zalando.com/restful-api-guidelines/#178))
 - Use REST maturity level 2 ([#162](https://opensource.zalando.com/restful-api-guidelines/#162))
 - Use common hypertext controls ([#164](https://opensource.zalando.com/restful-api-guidelines/#164))
 - Use full, absolute URI for resource identification (with same host, if applicable) ([#217](https://opensource.zalando.com/restful-api-guidelines/#217))
 - Not use link headers with JSON entities ([#166](https://opensource.zalando.com/restful-api-guidelines/#166))
 - Support pagination ([#159](https://opensource.zalando.com/restful-api-guidelines/#159))
 - Not break backward compatibility ([#106](https://opensource.zalando.com/restful-api-guidelines/#106))
 - Design API conservatively ([#109](https://opensource.zalando.com/restful-api-guidelines/#109))
 - Prepare clients to accept compatible API extensions ([#108](https://opensource.zalando.com/restful-api-guidelines/#108))
 - Treat OpenAPI specification as open for extension by default ([#111](https://opensource.zalando.com/restful-api-guidelines/#111))
 - Use media type versioning ([#114](https://opensource.zalando.com/restful-api-guidelines/#114))
 - Always return JSON objects as top-level data structures ([#110](https://opensource.zalando.com/restful-api-guidelines/#110))
 - Reflect deprecation in API specifications ([#187](https://opensource.zalando.com/restful-api-guidelines/#187))

### SHOULD

 - Secure endpoints ([#104](https://opensource.zalando.com/restful-api-guidelines/#104))
 - Define and assign permissions (scopes) ([#105](https://opensource.zalando.com/restful-api-guidelines/#105))
 - Follow the naming convention for permissions (scopes) ([#225](https://opensource.zalando.com/restful-api-guidelines/#225))
 - Use appropriate formats for date and time properties ([#255](https://opensource.zalando.com/restful-api-guidelines/#255))
 - Use standard formats for time duration and interval properties ([#127](https://opensource.zalando.com/restful-api-guidelines/#127))
 - Define useful resources ([#140](https://opensource.zalando.com/restful-api-guidelines/#140))
 - Model complete business processes ([#139](https://opensource.zalando.com/restful-api-guidelines/#139))
 - Use normalized paths without empty path segments and trailing slashes ([#136](https://opensource.zalando.com/restful-api-guidelines/#136))
 - Design single resource schema for reading and writing ([#252](https://opensource.zalando.com/restful-api-guidelines/#252))
 - Use standard media types ([#172](https://opensource.zalando.com/restful-api-guidelines/#172))
 - Use naming convention for date/time properties ([#235](https://opensource.zalando.com/restful-api-guidelines/#235))
 - Define maps using additionalProperties ([#216](https://opensource.zalando.com/restful-api-guidelines/#216))
 - Not use null for empty arrays ([#124](https://opensource.zalando.com/restful-api-guidelines/#124))
 - Only use most common HTTP status codes ([#150](https://opensource.zalando.com/restful-api-guidelines/#150))
 - Not use redirection codes ([#251](https://opensource.zalando.com/restful-api-guidelines/#251))
 - Use Location header instead of Content-Location header ([#180](https://opensource.zalando.com/restful-api-guidelines/#180))
 - Use simple hypertext controls for pagination and self-references ([#165](https://opensource.zalando.com/restful-api-guidelines/#165))
 - Use gzip compression ([#156](https://opensource.zalando.com/restful-api-guidelines/#156))
 - Support partial responses via filtering ([#157](https://opensource.zalando.com/restful-api-guidelines/#157))
 - Allow optional embedding of sub-resources ([#158](https://opensource.zalando.com/restful-api-guidelines/#158))
 - Document cacheable GET, HEAD, and POST endpoints ([#227](https://opensource.zalando.com/restful-api-guidelines/#227))
 - Prefer cursor-based pagination, avoid offset-based pagination ([#160](https://opensource.zalando.com/restful-api-guidelines/#160))
 - Use pagination response page object ([#248](https://opensource.zalando.com/restful-api-guidelines/#248))
 - Use pagination links ([#161](https://opensource.zalando.com/restful-api-guidelines/#161))
 - Avoid a total result count ([#254](https://opensource.zalando.com/restful-api-guidelines/#254))
 - Prefer compatible extensions ([#107](https://opensource.zalando.com/restful-api-guidelines/#107))
 - Avoid versioning ([#113](https://opensource.zalando.com/restful-api-guidelines/#113))
 - Use open-ended list of values (via examples) for enumeration types ([#112](https://opensource.zalando.com/restful-api-guidelines/#112))
 - Add Deprecation and Sunset header to responses ([#189](https://opensource.zalando.com/restful-api-guidelines/#189))

### Departures

These rules differ from Zalando's in the following ways:

**Dropped:** Zalando rules that don't apply to hydra-pleco.

- #184 Propagate proprietary headers, #192 Publish OpenAPI specification for APIs,
  #215 Provide API identifiers, #219 Provide API audience, #223–#224 (naming schemas),
  #233 Support `X-Flow-ID` and the Nakadi event rules. **Rationale**: these rely on Zalando's
  infrastructure.
- #153 Use code 429 with headers for rate limits. **Rationale**: hydra-pleco has no rate 
  limiting.
- #170 Use standard formats for country, language and currency properties. **Rationale**:
  pleco has no such properties.
- #234 Only use durable and immutable remote references. **Rationale**: the spec is 
  generated and has no remote references.

**Demoted to SHOULD:**

- #104 Secure endpoints, #105 Define and assign permissions (scopes) and #225 Follow
  the naming convention for permissions (scopes). **Rationale**: authentication has not 
  yet been implemented.
- #136 Use normalized paths without empty path segments and trailing slashes
- #227 Document cacheable GET, HEAD, and POST endpoints

**Promoted to MUST:**

- #109 Design API conservatively
- #120 Pluralize array names
- #132 Use kebab-case with uppercase separate words for HTTP headers
- #147 Limit number of sub-resource levels
- #240 Declare enum values using UPPER_SNAKE_CASE string

## CLI Guidelines

CLI rules are adapted from the
[Command Line Interface Guidelines](https://clig.dev/), and each rule links to the
section it comes from. MUST and SHOULD have the same meaning as in the API guidelines.

### MUST

 - Use a command-line argument parsing library where you can ([The Basics](https://clig.dev/#the-basics))
 - Return zero exit code on success, non-zero on failure ([The Basics](https://clig.dev/#the-basics))
 - Send output to `stdout` ([The Basics](https://clig.dev/#the-basics))
 - Send messaging to `stderr` ([The Basics](https://clig.dev/#the-basics))
 - If `stdout` is not an interactive terminal, don't display any animations ([Output](https://clig.dev/#output))
 - By default, don't output information that's only understandable by the creators of the software ([Output](https://clig.dev/#output))
 - Don't treat `stderr` like a log file, at least not by default ([Output](https://clig.dev/#output))
 - Only use one-letter flags for commonly used flags ([Arguments and flags](https://clig.dev/#arguments-and-flags))
 - Never *require* a prompt ([Arguments and flags](https://clig.dev/#arguments-and-flags))
 - Do not read secrets directly from flags ([Arguments and flags](https://clig.dev/#arguments-and-flags))
 - Only use prompts or interactive elements if `stdin` is an interactive terminal (a TTY) ([Interactivity](https://clig.dev/#interactivity))
 - If `--no-input` is passed, don't prompt or do anything interactive ([Interactivity](https://clig.dev/#interactivity))
 - If you're prompting for a password, don't print it as the user types ([Interactivity](https://clig.dev/#interactivity))
 - Don't have ambiguous or similarly-named commands ([Subcommands](https://clig.dev/#subcommands))
 - Don't have a catch-all subcommand ([Future-proofing](https://clig.dev/#future-proofing))
 - Don't allow arbitrary abbreviations of subcommands ([Future-proofing](https://clig.dev/#future-proofing))
 - Don't create a "time bomb" ([Future-proofing](https://clig.dev/#future-proofing))
 - For maximum portability, environment variable names must only contain uppercase letters, numbers, and underscores (and mustn't start with a number) ([Environment variables](https://clig.dev/#environment-variables))
 - Don't use `.env` as a substitute for a proper configuration file ([Environment variables](https://clig.dev/#environment-variables))
 - Do not read secrets from environment variables ([Environment variables](https://clig.dev/#environment-variables))
 - Do not phone home usage or crash data without consent ([Analytics](https://clig.dev/#analytics))

### SHOULD

 - Display extensive help text when asked ([Help](https://clig.dev/#help))
 - Display concise help text by default ([Help](https://clig.dev/#help))
 - Show full help when `-h` and `--help` are passed ([Help](https://clig.dev/#help))
 - Lead with examples ([Help](https://clig.dev/#help))
 - Display the most common flags and commands at the start of the help text ([Help](https://clig.dev/#help))
 - Use formatting in your help text ([Help](https://clig.dev/#help))
 - Human-readable output is paramount ([Output](https://clig.dev/#output))
 - Have machine-readable output where it does not impact usability ([Output](https://clig.dev/#output))
 - If human-readable output breaks machine-readable output, use `--plain` to display output in plain, tabular text format for integration with tools like `grep` or `awk` ([Output](https://clig.dev/#output))
 - Display output as formatted JSON if `--json` is passed ([Output](https://clig.dev/#output))
 - Suggest commands the user should run ([Output](https://clig.dev/#output))
 - Disable color if your program is not in a terminal or the user requested it ([Output](https://clig.dev/#output))
 - Use a pager (e.g. `less`) if you are outputting a lot of text ([Output](https://clig.dev/#output))
 - Catch errors and rewrite them for humans ([Errors](https://clig.dev/#errors))
 - Signal-to-noise ratio is crucial ([Errors](https://clig.dev/#errors))
 - If you've got two or more arguments for different things, you're probably doing something wrong ([Arguments and flags](https://clig.dev/#arguments-and-flags))
 - Use standard names for flags, if there is a standard ([Arguments and flags](https://clig.dev/#arguments-and-flags))
 - Make the default the right thing for most users ([Arguments and flags](https://clig.dev/#arguments-and-flags))
 - Be consistent across subcommands ([Subcommands](https://clig.dev/#subcommands))
 - Use consistent names for multiple levels of subcommand ([Subcommands](https://clig.dev/#subcommands))
 - Show progress if something takes a long time ([Robustness](https://clig.dev/#robustness-guidelines))
 - Make things time out ([Robustness](https://clig.dev/#robustness-guidelines))
 - If a user hits Ctrl-C (the INT signal), exit as soon as possible ([Signals](https://clig.dev/#signals))
 - Use flags (for configuration that varies with each invocation) ([Configuration](https://clig.dev/#configuration))
 - Use flags and probably environment variables too (for configuration that varies per machine) ([Configuration](https://clig.dev/#configuration))
 - Check general-purpose environment variables for configuration values when possible ([Environment variables](https://clig.dev/#environment-variables))

## Conventions

### Packages and modules

Imports are grouped: local `Hydra.Pleco.*` modules first, then a blank line, then
third-party modules:

```
import Hydra.Pleco.Api (Eval (..), EvalId (..))
import Hydra.Pleco.Server.DB qualified as DB
import Hydra.Pleco.Server.Error (noSuchEvalError)

import Servant (Handler, throwError)
```

Each top-level module re-exports its submodules, and is its tree's external interface
(eg, `Hydra.Pleco.Api`, `Hydra.Pleco.Server.DB`). A submodule can import its siblings or
modules of other trees, but not its direct parent. For example,
`Server.Handlers.Projects`:

- `Server.Handlers.Projects` can import `Server.Handlers.Jobsets` (sibling)
- `Server.Handlers.Projects` can import `Server.DB` (another tree)
- `Server.Handlers.Projects` **cannot** import `Server.Handlers` (parent)

**Rationale:** the parent can then always re-export it without an import cycle.

Handlers are grouped by resource under `Server.Handlers.<Resource>`, and each slice is
as self-contained as possible. Data access follows the the Hasql
[data-access architecture](https://github.com/nikita-volkov/hasql-docs/blob/main/data-access-architecture.md):

| Layer   | Module                          | Holds                                |
| ------- | ------------------------------- | ------------------------------------ |
| Mapping | `Server.DB.Hydra`               | Hydra schema and queries             |
| Access  | `Server.Handlers.<Resource>.DB` | Conversions between DB and API types |

Schemas and queries that we don't own go in `Server.DB.Hydra`.

**Rationale:** Hydra's schema rarely changes, while pleco's types change often. Keeping
them apart keeps `Server.DB.Hydra` stable.

### Haskell style

Formatting and lint are enforced by `just fmt` and `just lint`. Beyond those:

- The default `Prelude` is replaced by [relude](https://hackage.haskell.org/package/relude)
  `String` is avoided in favor of `Text`.
- JSON instances are hand-written, not derived through `Generic`.
  **Rationale:** a new field then has to be handled deliberately. The compiler or tests
  warn about missing fields in `FromJSON`/`ToJSON`.

### Errors

- API errors are `application/problem+json`, as defined by
  [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457). Each type of error is a constructor
  of `ProblemType`, and the response is built with `serverError`
  (`Hydra.Pleco.Server.Error`).
- The CLI maps failures to a `PlecoClientError`s. It renders the error to stderr as a
  description, an optional detail and an optional hint, then exits non-zero.

### Tests

Tests use [hspec](https://hspec.github.io/). Tests are placed in the suite that match
their needs:

| Suite                              | Holds                                          |
| ---------------------------------- | ---------------------------------------------- |
| `hydra-pleco-api:test:tests`       | Pure API type tests (JSON and OpenAPI checks)  |
| `hydra-pleco-server:test:tests`    | Pure server tests, behaviour with no DB        |
| `hydra-pleco-server:test:db-tests` | DB integration and end-to-end functional tests |
| `hydra-pleco-cli:test:tests`       | Pure error mapping and formatting tests        |

They follow these additional conventions:

- Shared generators/harnesses go in a `testlib` sublibrary
- Each API type has Aeson round-trip property tests (`tripping`) and a schema check
  (`validateToJSON`). **Rationale**: Keeps OpenAPI schema and Aeson instances in
  agreement.
- Tests are named after the module under test (eg,
  `Hydra.Pleco.Server.Handlers.Projects.DBSpec`), and contain a matching top-level
  `describe` (eg, `describe "Hydra.Pleco.Server.Handlers.Projects.DB"`)
- Golden files are in `data/<name>/golden`. To accept a change, delete `golden` and rerun
  the tests.
