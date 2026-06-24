# AGENTS.md

Guidance for AI coding agents working on the **Build CLI** (`bld`). Human
contributors may find it useful too. Keep changes small and conventional — this
is a focused tool, not a framework.

## What this is

`bld` is the command-line client for [Build.io](https://app.build.io), a
Heroku-compatible PaaS. It is written in **Crystal** and compiled to a single
binary distributed via GitHub Releases and Homebrew. It talks to the Build API
through the generated `build-client` SDK.

## Setup, build, and test

```bash
shards install                      # install dependencies (into ./lib)
shards build                        # build the binary -> ./bin/bld
crystal build src/build_cli.cr -o bin/bld   # equivalent direct build
crystal spec                        # run the test suite
```

Crystal >= 1.16 is required (see `shard.yml`). The build must compile cleanly and
`crystal spec` must pass before you open a PR.

## Layout

```
src/build_cli.cr     # entry point: configures the SDK and registers every command
src/commands/        # one file per command group (app, config, ps, addons, ...)
src/commands/base.cr # Base < ACON::Command: token(), api(), print_table() helpers
src/*.cr             # shared helpers (utils, env_format, log_colorizer)
spec/                # specs (crystal spec)
```

The CLI is built on the [athena-console](https://github.com/athena-framework/console)
framework (`ACON`).

## Adding or changing a command

Each command subclasses `Build::Commands::Base` and implements two methods:

```crystal
@[ACONA::AsCommand("things:list")]
class List < Base
  protected def configure : Nil
    self
      .name("things:list")          # the name registered here is authoritative
      .description("...")
      .option("app", "a", :optional, "The app.")
  end

  protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
    # use `api` (from Base) for SDK calls; return SUCCESS / FAILURE
    ACON::Command::Status::SUCCESS
  end
end
```

Then register it in `src/build_cli.cr` with `application.add Build::Commands::...new`.
Commands are registered eagerly there, so the `.name(...)` call in `configure`
is what takes effect — keep the `@[ACONA::AsCommand(...)]` annotation in sync
with it.

Conventions to follow:
- Offer `--json` / `-j` on read commands when it makes sense; many commands also
  support `-s` shell format.
- Get the auth token via `Base#token` (it honors `BUILD_API_KEY` then `~/.netrc`)
  rather than reading `~/.netrc` directly, so all commands behave consistently.
- Derive host/scheme from `Build.api_host` / `Build.api_host_scheme` rather than
  hardcoding `https`, so `BUILD_API_URL` (local dev) keeps working.

## Conventions and gotchas

- **Do not mass-reformat.** This repo is not kept `crystal tool format`-clean.
  Match the style of the surrounding code and keep diffs minimal; do not run the
  formatter across existing files.
- **Do not edit the SDK here.** `build-client` is generated in a separate repo
  (`buildio/sdk-crystal-lang`). Changes to API models/methods belong there.
- **Do not bump the version by hand.** `shard.yml`'s version and the SDK pin are
  updated by release automation (`.github/workflows/release.yml`) on SDK updates
  and tags. Leave them alone in feature PRs.
- **Do not commit build output.** `bin/`, `lib/`, `docs/`, and `.shards/` are
  gitignored.
- Commit messages follow the existing history: a short, imperative,
  capitalized subject (e.g. `Show git URL in apps:create output`). No
  Conventional Commits prefixes.

## Environment variables

- `BUILD_API_URL` — override the API base (default `https://app.build.io`).
- `BUILD_API_KEY` — bearer token, bypasses `~/.netrc`.
- `BUILD_DEFAULT_REGION` — default `us-east-1`.
- `DEBUG=1` — verbose CLI + SDK logging.

## Note: `bld skills`

The CLI has a `skills` command that prints a usage guide for AI agents that
*use* `bld` (deploying apps, reading config, etc.). That is distinct from this
file, which is for agents *developing* the CLI. If you change command names,
flags, or behavior, update `src/commands/skills.cr` to match.
