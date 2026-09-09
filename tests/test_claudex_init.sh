#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

"$ROOT/bin/claudex-init" user-login --cwd "$TMP"
assert_exit 0 $? "init exits 0"
assert_file_exists "$TMP/docs/claudex/user-login/tasks" "feature tasks dir"
assert_file_exists "$TMP/docs/claudex/user-login/01-requirements.md" "requirements from template"
assert_file_exists "$TMP/docs/claudex/evidence/INDEX.md" "evidence index"
assert_file_exists "$TMP/docs/claudex/decisions" "decisions dir"
assert_contains "$(cat "$TMP/docs/claudex/user-login/01-requirements.md")" "# Requirements: user-login" "slug substituted"

# idempotent: existing content untouched
echo "edited" > "$TMP/docs/claudex/user-login/01-requirements.md"
"$ROOT/bin/claudex-init" user-login --cwd "$TMP"
assert_eq "edited" "$(cat "$TMP/docs/claudex/user-login/01-requirements.md")" "does not overwrite"

# slug validation
"$ROOT/bin/claudex-init" "Bad Slug" --cwd "$TMP" 2>/dev/null
assert_exit 2 $? "rejects invalid slug"

test_summary
