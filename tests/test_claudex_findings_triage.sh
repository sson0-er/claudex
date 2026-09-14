#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(make_tmp)"

mkdir -p "$TMP/tasks"

cat > "$TMP/tasks/01-a.findings.quality.json" <<'EOF'
{"summary":"quality","findings":[
 {"severity":"low","title":"Duplicated helper.","location":"src/a.go:10","detail":"consolidate the two copies","evidence":""},
 {"severity":"low","title":"Overly clever one-liner","location":"src/b.go:5","detail":"simplify","evidence":""}
]}
EOF
cat > "$TMP/tasks/02-b.findings.quality.json" <<'EOF'
{"summary":"quality","findings":[
 {"severity":"low","title":"duplicated  helper","location":"src/c.go:20","detail":"","evidence":""}
]}
EOF
cat > "$TMP/tasks/02-b.findings.spec.json" <<'EOF'
{"summary":"spec","findings":[
 {"severity":"low","title":"design ambiguity: retention window","location":"","detail":"design is silent on the TTL","evidence":""}
]}
EOF
cat > "$TMP/tasks/03-c.findings.tests.json" <<'EOF'
{"summary":"tests","findings":[
 {"severity":"medium","title":"Missing boundary case","location":"t.go:1","detail":"add test","evidence":""},
 {"severity":"high","title":"Flaky test","location":"t.go:2","detail":"fix flake","evidence":""}
]}
EOF

line="$("$ROOT/bin/claudex-findings-triage" --tasks-dir "$TMP/tasks" --out "$TMP/out.md")"
assert_exit 0 $? "triage exits 0"
assert_eq "raw: 4 merged: 3" "$line" "stdout summary line"

out="$(cat "$TMP/out.md")"
assert_contains "$out" "raw: 4, merged: 3, by role: quality 2, security 0, spec 1, tests 0" "header counts"
assert_contains "$out" "L001" "id L001 assigned"
assert_contains "$out" "L002" "id L002 assigned"
assert_contains "$out" "L003" "id L003 assigned"
assert_contains "$out" "(2 occurrences; tasks: 01-a, 02-b)" "duplicated-helper merge across tasks"
assert_contains "$out" "## Pre-assigned B (design ambiguity)" "pre-assigned B section present"
assert_contains "$out" "design ambiguity: retention window" "B item rendered"
case "$out" in
  *"### tests"*) fail "no ### tests heading (tests role contributed no lows)" ;;
  *) pass ;;
esac

# Empty tasks dir: no findings files at all.
mkdir -p "$TMP/empty"
line2="$("$ROOT/bin/claudex-findings-triage" --tasks-dir "$TMP/empty" --out "$TMP/out2.md")"
assert_exit 0 $? "empty dir exits 0"
assert_eq "raw: 0 merged: 0" "$line2" "empty dir stdout summary"
out2="$(cat "$TMP/out2.md")"
assert_contains "$out2" "raw: 0, merged: 0, by role: quality 0, security 0, spec 0, tests 0" "empty dir header counts"
assert_contains "$out2" "No low findings." "empty dir body"

# Invalid findings JSON exits 2 and does not write the output file.
mkdir -p "$TMP/bad"
echo 'not json' > "$TMP/bad/01-x.findings.quality.json"
"$ROOT/bin/claudex-findings-triage" --tasks-dir "$TMP/bad" --out "$TMP/out3.md" 2>/dev/null
assert_exit 2 $? "invalid findings json exits 2"
[ ! -e "$TMP/out3.md" ] && pass "output file not written on error" || fail "output file should not exist after error"

# Missing --out is a usage error.
"$ROOT/bin/claudex-findings-triage" --tasks-dir "$TMP/tasks" 2>/dev/null
assert_exit 2 $? "missing --out exits 2"

# Missing --tasks-dir is a usage error.
"$ROOT/bin/claudex-findings-triage" --out "$TMP/out4.md" 2>/dev/null
assert_exit 2 $? "missing --tasks-dir exits 2"

# Nonexistent tasks dir exits 2.
"$ROOT/bin/claudex-findings-triage" --tasks-dir "$TMP/does-not-exist" --out "$TMP/out5.md" 2>/dev/null
assert_exit 2 $? "nonexistent tasks dir exits 2"

test_summary
