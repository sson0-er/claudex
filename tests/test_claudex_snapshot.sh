#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(cd "$(make_tmp)" && pwd)"

# Set up a repo with one committed file, a .gitignore, and later some
# tracked/untracked/ignored changes to snapshot.
mkdir -p "$TMP/repo"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.email "test@example.com"
git -C "$TMP/repo" config user.name "Test"
echo "one" > "$TMP/repo/a.txt"
echo "*.log" > "$TMP/repo/.gitignore"
git -C "$TMP/repo" add a.txt .gitignore
git -C "$TMP/repo" commit -q -m "initial"

head_before="$(git -C "$TMP/repo" rev-parse HEAD)"

echo "two" > "$TMP/repo/a.txt"
echo "untracked" > "$TMP/repo/b.txt"
echo "ignored" > "$TMP/repo/c.log"

status_before="$(git -C "$TMP/repo" status --porcelain)"
sha1="$("$ROOT/bin/claudex-snapshot" --cwd "$TMP/repo")"
assert_exit 0 $? "snapshot exits 0"
case "$sha1" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
    pass ;;
  *) fail "snapshot did not print 40 hex chars: '$sha1'" ;;
esac

diffnames="$(git -C "$TMP/repo" diff --name-only HEAD "$sha1")"
assert_contains "$diffnames" "a.txt" "snapshot diff includes modified tracked file"
assert_contains "$diffnames" "b.txt" "snapshot diff includes untracked file"
case "$diffnames" in
  *c.log*) fail "snapshot diff must not include ignored file" ;;
  *) pass ;;
esac

head_after="$(git -C "$TMP/repo" rev-parse HEAD)"
assert_eq "$head_before" "$head_after" "HEAD unchanged after snapshot"

status_after="$(git -C "$TMP/repo" status --porcelain)"
assert_eq "$status_before" "$status_after" "working tree status unchanged after snapshot (byte-identical)"

# Change only b.txt and take a second snapshot: SHA differs, and the diff
# between the two snapshots is exactly the one changed file.
echo "changed again" > "$TMP/repo/b.txt"
sha2="$("$ROOT/bin/claudex-snapshot" --cwd "$TMP/repo")"
assert_exit 0 $? "second snapshot exits 0"
if [ "$sha1" != "$sha2" ]; then pass; else fail "second snapshot must differ from first"; fi
diffnames2="$(git -C "$TMP/repo" diff --name-only "$sha1" "$sha2")"
assert_eq "b.txt" "$diffnames2" "diff between snapshots is exactly the changed file"

# Non-git directory exits 3. $TMP itself lives under this project's own
# repo (tests/.tmp/...), so use a directory outside any repo instead.
notgit="$(mktemp -d "${TMPDIR:-/tmp}/claudex-snapshot-notgit.XXXXXX")"
trap 'rm -rf "$notgit"' EXIT
"$ROOT/bin/claudex-snapshot" --cwd "$notgit" >/dev/null 2>&1
assert_exit 3 $? "non-git directory exits 3"
rm -rf "$notgit"
trap - EXIT

# Missing option value exits 2.
"$ROOT/bin/claudex-snapshot" --cwd >/dev/null 2>&1
assert_exit 2 $? "missing --cwd value exits 2"

# No temp file left behind in TMPDIR across all the runs above.
before="$(ls "${TMPDIR:-/tmp}" | grep -c '^claudex-snapshot\.')"
"$ROOT/bin/claudex-snapshot" --cwd "$TMP/repo" >/dev/null
after="$(ls "${TMPDIR:-/tmp}" | grep -c '^claudex-snapshot\.')"
assert_eq "$before" "$after" "no claudex-snapshot temp file leaked"

test_summary
