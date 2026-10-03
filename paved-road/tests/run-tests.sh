#!/usr/bin/env bash
# Local tests for the security stages, without GitHub Actions. CI runs the same cases
# through the composite action itself (see .github/workflows/test.yml).
# Needs Linux, bash 4+, curl, jq, python3 with venv, and network access (downloads the
# tools; osv-scanner asks the OSV API). On macOS, run it in Docker:
#   docker run --rm -v "$PWD:/repo:ro" -w /repo ubuntu:24.04 bash -c \
#     'apt-get update -qq && apt-get install -y -qq curl ca-certificates jq python3-venv git >/dev/null &&
#      git config --global --add safe.directory /repo && paved-road/tests/run-tests.sh'
# semgrep only scans files git tracks, so commit new fixtures before running it.
set -u
cd "$(dirname "$0")" || exit 1
stages=../security-stages/scripts
fixtures=fixtures
tools=${TOOLS_DIR:-$(mktemp -d)}
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

"$stages/install-tools.sh" "$tools" || { echo "FAIL install-tools"; exit 1; }

# expect NAME WANT_EXIT WANT_RESULTS FIXTURE [VAR=VALUE ...]
#   WANT_RESULTS is "secrets/sca/sast", for example "findings/pass/pass".
expect() {
  local name=$1 want_rc=$2 want=$3 dir=$4 out rc got
  shift 4
  out=$(env TOOLS_DIR="$tools" SCAN_PATH="$fixtures/$dir" GITHUB_STEP_SUMMARY=/dev/null \
    GITHUB_OUTPUT=/dev/stdout "$@" "$stages/run-stages.sh" 2>&1)
  rc=$?
  got="$(sed -n 's/^secrets-result=//p' <<<"$out")/$(sed -n 's/^sca-result=//p' <<<"$out")/$(sed -n 's/^sast-result=//p' <<<"$out")"
  if [ "$rc" -eq "$want_rc" ] && [ "$got" = "$want" ]; then
    pass "$name"
  else
    fail "$name (exit $rc, want $want_rc; results $got, want $want)"
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

echo "== run-stages.sh"
expect clean-passes            0 pass/pass/pass         clean
expect secret-blocks           1 findings/pass/pass     planted-secret
expect secret-off-passes       0 off/pass/pass          planted-secret SECRETS_MODE=off
expect secret-warn-passes      0 findings/pass/pass     planted-secret SECRETS_MODE=warn
expect vuln-dep-warns          0 pass/findings/pass     vulnerable-dependency
expect vuln-dep-blocks         1 pass/findings/pass     vulnerable-dependency SCA_MODE=block
expect insecure-code-warns     0 pass/pass/findings     insecure-code
expect insecure-code-blocks    1 pass/pass/findings     insecure-code SAST_MODE=block
expect bad-mode-rejected       2 //                     clean SCA_MODE=maybe

echo "== semgrep rules"
if "$tools/bin/semgrep" --test --metrics=off --disable-version-check \
    --config ../security-stages/semgrep-rules/ semgrep-rules/ >/dev/null 2>&1; then
  pass semgrep-rule-tests
else
  fail semgrep-rule-tests
  "$tools/bin/semgrep" --test --metrics=off --disable-version-check \
    --config ../security-stages/semgrep-rules/ semgrep-rules/ 2>&1 | sed 's/^/    /'
fi

exit $status
