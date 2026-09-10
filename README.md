# claudex

A Claude Code plugin that makes Claude Code the orchestrator and delegates to role-specific Claude subagents and the Codex CLI.

## Prerequisites

- Claude Code, the Codex CLI (`codex` on PATH), and `jq`
- macOS or Linux (bash 3.2 or newer)
- In the target project: `scripts/verify.sh`, one executable that runs lint, type checks, build, tests and prints a coverage summary (must be executable; `CLAUDEX_VERIFY_CMD` takes a single executable path, no arguments)
- In the target project: `AGENTS.md` with the project conventions (Codex reads it; import it from `CLAUDE.md` with `@AGENTS.md`)

## Install

For personal use, copy the plugin into Claude Code's skills directory, where it auto-loads in every session as `claudex@skills-dir`:

```
./install.sh
```

The destination is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/claudex` (override with `--dest DIR`). Run `/reload-plugins` to load it without restarting. Re-run `./install.sh` after changing the plugin; it replaces the previous copy. To remove it, delete that directory, or disable it with `claude plugin disable claudex@skills-dir`.

While developing, you can instead load the repo directly for one session:

```
claude --plugin-dir /path/to/claudex
```

Publishing through a private marketplace (for example a `~/.claudex` directory with a `.claude-plugin/marketplace.json`) is a possible later step; it is not set up yet.

## Usage

From the target project root, inside a Claude Code session:

```
/claudex:orchestrate <feature-slug>
```

Plugin skills are always namespaced with the plugin name, so the short form `/orchestrate` does not exist.

The flow is: requirements (interactive), research, design, Codex design review, plan, then per task Codex implementation, verify gate, four parallel reviews and a bounded fix loop, then documentation. It stops for explicit approval after requirements, after design, and after the plan.

## Layout

| Path | Role |
|---|---|
| `bin/claudex-codex` | Role-based Codex launcher (design-review / implement / fix) |
| `bin/claudex-verify` | Verify gate: runs `scripts/verify.sh` and keeps the log |
| `bin/claudex-findings-merge` | Merges review findings and applies a severity threshold |
| `bin/claudex-init` | Creates the `docs/claudex/` layout |
| `bin/claudex-snapshot` | Snapshots the working tree as a commit object so later review rounds diff only the fix |
| `agents/` | researcher, designer, planner, reviewer-{quality,security,spec,tests}, doc-writer |
| `skills/` | orchestrate (full flow), define-requirements (interactive), record-evidence (recording rules) |
| `templates/` | Artifact templates |
| `schemas/` | JSON Schemas for findings and reports |
| `install.sh` | Copies the runtime files into the skills directory (see Install) |

Artifacts live under `docs/claudex/` in the target project. Evidence (recorded external facts) and decisions (recorded design choices) accumulate across features.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `CLAUDEX_CODEX_BIN` | `codex` | Codex executable (tests point it at a fake) |
| `CLAUDEX_MODEL_DESIGN_REVIEW` | `gpt-5.6-sol` | Model for design review |
| `CLAUDEX_MODEL_IMPLEMENT` | `gpt-5.6-luna` | Model for implementation and fixes |
| `CLAUDEX_VERIFY_CMD` | `scripts/verify.sh` | Verify gate command |

## Tests

```
bash tests/run.sh
```

No external dependencies beyond `jq`. Codex is replaced by `tests/fixtures/fake-codex`.
To run the same suite on Linux with Docker:

```
docker run --rm -v "$PWD":/w -w /w alpine:3 sh -c 'apk add -q bash jq git && bash tests/run.sh'
```
