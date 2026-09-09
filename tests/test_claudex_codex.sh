#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Absolute, because the fix role now cd's into --cwd (codex exec resume
# has no -C flag) and a relative TMP would then resolve against that dir.
TMP="$(make_tmp)"
TMP="$(cd "$TMP" && pwd)"
export CLAUDEX_CODEX_BIN="$ROOT/tests/fixtures/fake-codex"
export FAKE_CODEX_ARGS="$TMP/args.txt"
echo "review this" > "$TMP/prompt.md"

# design-review: read-only, sol/high, findings schema, last agent message captured
"$ROOT/bin/claudex-codex" design-review --prompt-file "$TMP/prompt.md" --out "$TMP/out.json" \
  --thread-file "$TMP/thread.txt" --cwd "$TMP"
assert_exit 0 $? "design-review exits 0"
args="$(cat "$FAKE_CODEX_ARGS")"
assert_contains "$args" "exec" "uses codex exec"
assert_contains "$args" "gpt-5.6-sol" "design-review model"
assert_contains "$args" 'model_reasoning_effort="high"' "design-review effort"
assert_contains "$args" "read-only" "design-review sandbox"
assert_contains "$args" "findings.schema.json" "design-review schema"
assert_contains "$args" "review this" "prompt passed through"
assert_eq "t-fake-123" "$(cat "$TMP/thread.txt")" "thread id captured"
assert_eq '{"summary":"ok","findings":[]}' "$(cat "$TMP/out.json")" "last agent message written"

# implement: workspace-write, luna/xhigh, report schema
"$ROOT/bin/claudex-codex" implement --prompt-file "$TMP/prompt.md" --out "$TMP/out2.json" --cwd "$TMP"
args="$(cat "$FAKE_CODEX_ARGS")"
assert_contains "$args" "gpt-5.6-luna" "implement model"
assert_contains "$args" 'model_reasoning_effort="xhigh"' "implement effort"
assert_contains "$args" "workspace-write" "implement sandbox"
assert_contains "$args" "report.schema.json" "implement schema"

# fix: resume with thread, model/sandbox via -c (resume has no -m / -s flags)
export FAKE_CODEX_PWD="$TMP/fix-pwd.txt"
"$ROOT/bin/claudex-codex" fix --thread t-fake-123 --prompt-file "$TMP/prompt.md" --out "$TMP/out3.json" --cwd "$TMP"
assert_exit 0 $? "fix exits 0"
args="$(cat "$FAKE_CODEX_ARGS")"
assert_contains "$args" "resume" "fix uses resume"
assert_contains "$args" "t-fake-123" "fix passes thread id"
assert_contains "$args" 'model="gpt-5.6-luna"' "fix model via -c"
assert_contains "$args" 'sandbox_mode="workspace-write"' "fix sandbox via -c"
assert_contains "$args" "report.schema.json" "fix schema"
# fix cd's into --cwd (codex exec resume has no -C flag); confirm codex actually ran there.
assert_eq "$TMP" "$(cat "$TMP/fix-pwd.txt")" "fix runs codex in --cwd directory"
unset FAKE_CODEX_PWD
# Verified against real codex-cli 0.153.4: `codex exec resume` rejects -C
# ("error: unexpected argument '-C' found"), so fix must not pass it.
case "$args" in
  *"-C"*) fail "fix must not pass -C (codex exec resume rejects it)" ;;
  *) pass ;;
esac

# fix without --thread is a usage error
"$ROOT/bin/claudex-codex" fix --prompt-file "$TMP/prompt.md" --out "$TMP/out4.json" 2>/dev/null
assert_exit 2 $? "fix requires --thread"

# codex failure propagates
FAKE_CODEX_EXIT=7 "$ROOT/bin/claudex-codex" implement --prompt-file "$TMP/prompt.md" --out "$TMP/out5.json" --cwd "$TMP" 2>/dev/null
assert_exit 7 $? "codex exit code propagates"

# user-supplied --events file is kept and populated
"$ROOT/bin/claudex-codex" implement --prompt-file "$TMP/prompt.md" --out "$TMP/out6.json" --cwd "$TMP" \
  --events "$TMP/ev.jsonl"
assert_file_exists "$TMP/ev.jsonl" "user-supplied --events file exists"
assert_contains "$(cat "$TMP/ev.jsonl")" "thread.started" "user-supplied --events file has events"

# auto-created events file is cleaned up (no leak in TMPDIR)
before="$(ls "${TMPDIR:-/tmp}" 2>/dev/null | grep -c '^claudex-codex-events\.')"
"$ROOT/bin/claudex-codex" implement --prompt-file "$TMP/prompt.md" --out "$TMP/out7.json" --cwd "$TMP"
after="$(ls "${TMPDIR:-/tmp}" 2>/dev/null | grep -c '^claudex-codex-events\.')"
assert_eq "$before" "$after" "auto-created events file cleaned up"

# missing option value exits 2
"$ROOT/bin/claudex-codex" implement --prompt-file 2>/dev/null
assert_exit 2 $? "missing --prompt-file value exits 2"

test_summary
