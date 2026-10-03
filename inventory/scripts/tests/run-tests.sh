#!/usr/bin/env bash
# Tests for list-actions.sh. Runs offline against the fake repos in fixtures/repos.
# Each case compares the exact output with a file in expected/.
set -u
cd "$(dirname "$0")" || exit 1
script=../list-actions.sh
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

# same NAME EXPECTED_FILE ARGS...: the output must match the expected file exactly.
same() {
  name=$1 want=$2; shift 2
  if out=$("$script" "$@" 2>&1) && [ "$out" = "$(cat "$want")" ]; then
    pass "$name"
  else
    fail "$name"
    printf '%s\n' "$out" | diff "$want" - || true
  fi
}

# rejects NAME ARGS...: the script must exit with status 2 (usage error).
rejects() {
  name=$1; shift
  "$script" "$@" >/dev/null 2>&1
  rc=$?
  if [ $rc -eq 2 ]; then pass "$name"; else fail "$name (exit $rc, want 2)"; fi
}

echo "== list-actions.sh"
same all-actions     expected/all.tsv      fixtures/repos
same trailing-slash  expected/all.tsv      fixtures/repos/
same unpinned-only   expected/unpinned.tsv --unpinned-only fixtures/repos
rejects no-args
rejects missing-folder fixtures/no-such-folder
rejects too-many-args  fixtures/repos fixtures/repos

exit $status
