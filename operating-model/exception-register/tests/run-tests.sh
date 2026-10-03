#!/usr/bin/env bash
# Tests for both checks. Runs offline: the approval tests use JSON fixtures, not the GitHub API.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
check=scripts/check-exceptions.sh
approvals=scripts/check-approvals.sh
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

# expect NAME pass|fail [TEXT] -- COMMAND...: the command must pass or fail, and print TEXT if given.
expect() {
  local name=$1 want=$2 text=$3 out rc; shift 4
  out=$("$@" 2>&1); rc=$?
  if [[ "$want" == pass && $rc -ne 0 ]]; then fail "$name (should pass): $out"; return; fi
  if [[ "$want" == fail && $rc -eq 0 ]]; then fail "$name (should fail)"; return; fi
  if [[ -n "$text" && "$out" != *"$text"* ]]; then fail "$name (expected \"$text\"): $out"; return; fi
  pass "$name"
}

echo "== check-exceptions.sh"
expect valid pass "" -- "$check" tests/valid/exceptions
# Each invalid fixture must fail for its own reason, given in its expect file.
for d in tests/invalid/*/; do
  name=$(basename "$d")
  expect "$name" fail "$(cat "$d/expect")" -- "$check" "$d/exceptions"
done
# With a list of files, only those files are checked (pull requests check changed files only).
expect files-only-valid pass "" -- "$check" tests/valid/exceptions/p2/test.yaml tests/valid/exceptions/p4/test.yaml
expect files-one-invalid fail "expired on" -- "$check" tests/valid/exceptions/p2/test.yaml tests/invalid/expired/exceptions/p3/test.yaml
expect files-missing fail "no such file" -- "$check" tests/valid/exceptions/p2/nope.yaml

echo "== check-approvals.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
head=abc123

# review LOGIN STATE [COMMIT]: one review, as the GitHub API returns it.
review() { printf '{"user":{"login":"%s"},"state":"%s","commit_id":"%s"}' "$1" "$2" "${3:-$head}"; }
# case NAME pass|fail TEXT "FOLDER..." REVIEW...
case_() {
  local name=$1 want=$2 text=$3 folders=$4 i=0 r json=""; shift 4
  # Reviews are submitted in the order given.
  for r in "$@"; do
    i=$((i + 1))
    json+="${json:+,}${r%\}},\"submitted_at\":\"2099-01-01T00:00:$(printf %02d "$i")Z\"}"
  done
  echo "[$json]" > "$work/$name.json"
  # shellcheck disable=SC2086 # folders is a space-separated list on purpose
  expect "approvals: $name" "$want" "$text" -- \
    "$approvals" --decide approvers.yaml "$work/$name.json" tests/approvals/members.json "$head" $folders
}

case_ p2-both               pass "" p2 "$(review vp APPROVED)" "$(review head-sec APPROVED)"
case_ p2-acceptor-only      fail "needs an approval from @security-leadership" p2 "$(review vp APPROVED)"
case_ p2-security-only      fail "needs an approval from @vp-eng" p2 "$(review head-sec APPROVED)"
case_ p2-one-person-both    fail "two different people" p2 "$(review dual APPROVED)"
case_ p2-dual-plus-other    pass "" p2 "$(review dual APPROVED)" "$(review head-sec APPROVED)"
case_ p2-wrong-teams        fail "needs an approval from @vp-eng" p2 "$(review manager APPROVED)" "$(review appsec-eng APPROVED)"
case_ p2-later-changes      fail "needs an approval from @vp-eng" p2 \
  "$(review vp APPROVED)" "$(review head-sec APPROVED)" "$(review vp CHANGES_REQUESTED)"
case_ p2-comment-keeps      pass "" p2 "$(review vp APPROVED)" "$(review head-sec APPROVED)" "$(review vp COMMENTED)"
case_ p2-dismissed          fail "needs an approval from @security-leadership" p2 "$(review vp APPROVED)" "$(review head-sec DISMISSED)"
case_ p2-stale-commit       fail "needs an approval from @vp-eng" p2 "$(review vp APPROVED old999)" "$(review head-sec APPROVED)"
case_ p1-both               pass "" p1 "$(review cto APPROVED)" "$(review ciso APPROVED)"
case_ p3-both               pass "" p3 "$(review director APPROVED)" "$(review appsec-lead APPROVED)"
case_ p4-both               pass "" p4 "$(review manager APPROVED)" "$(review appsec-eng APPROVED)"
case_ p4-acceptor-only      fail "needs an approval from @appsec" p4 "$(review manager APPROVED)"
case_ hygiene-acceptor-only pass "" hygiene "$(review manager APPROVED)"
case_ hygiene-appsec-only   fail "needs an approval from @eng-managers" hygiene "$(review appsec-eng APPROVED)"
case_ two-folders-one-done  fail "exceptions/p1/ needs an approval from @exec-approvers" "p1 p2" \
  "$(review vp APPROVED)" "$(review head-sec APPROVED)" "$(review ciso APPROVED)"
case_ unknown-folder        fail "has no approvers" archive "$(review vp APPROVED)"
case_ no-folders            pass "" ""

exit $status
