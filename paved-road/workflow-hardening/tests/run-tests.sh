#!/usr/bin/env bash
# Tests for the workflow-hardening fixtures. zizmor must flag the insecure workflow and
# pass the hardened one; actionlint must pass the hardened one.
# Usage: run-tests.sh LINTERS_DIR   (a folder made by install-linters.sh)
# Needs bash and jq. Offline: zizmor runs with --offline.
set -u
if [ $# -ne 1 ]; then echo "usage: run-tests.sh LINTERS_DIR" >&2; exit 2; fi
bin=$1/bin
cd "$(dirname "$0")/fixtures" || exit 1
status=0 rc=0 ids="" config=""
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

# run_zizmor PERSONA DIR: sets rc to zizmor's exit code and ids to the audit IDs it
# reported, one per line.
run_zizmor() {
  local out
  out=$("$bin/zizmor" --offline --no-progress --persona "$1" --format json ${config:+--config "$config"} "$2" 2>/dev/null)
  rc=$?
  ids=$(jq -r '.[].ident' <<<"$out" | sort -u)
}

# flags NAME PERSONA DIR AUDIT...: zizmor must exit with a findings code (11-14) and
# report every listed audit.
flags() {
  local name=$1 persona=$2 dir=$3 missing=""
  shift 3
  run_zizmor "$persona" "$dir"
  for a in "$@"; do grep -qx "$a" <<<"$ids" || missing="$missing $a"; done
  if [ "$rc" -ge 11 ] && [ "$rc" -le 14 ] && [ -z "$missing" ]; then pass "$name"
  else fail "$name (exit $rc; missing:${missing:- none}; got: $(echo "$ids" | tr '\n' ' '))"
  fi
}

# clean NAME PERSONA DIR: zizmor must report nothing and exit 0.
clean() {
  run_zizmor "$2" "$3"
  if [ "$rc" -eq 0 ] && [ -z "$ids" ]; then pass "$1"; else fail "$1 (exit $rc; got: $(echo "$ids" | tr '\n' ' '))"; fi
}

echo "== zizmor"
# The default persona is what workflow-lint.yml runs.
flags insecure-flagged-default  regular  insecure/.github/workflows dangerous-triggers unpinned-uses
flags insecure-flagged-pedantic pedantic insecure/.github/workflows dangerous-triggers unpinned-uses excessive-permissions artipacked
clean hardened-passes-default   regular  hardened/.github/workflows
clean hardened-passes-pedantic  pedantic hardened/.github/workflows
# Internal actions by branch: flagged by default, allowed by zizmor.yml.
flags internal-ref-default-flagged regular internal-ref/.github/workflows unpinned-uses
config=../../zizmor.yml
clean internal-ref-allowed-by-config regular internal-ref/.github/workflows
config=""

echo "== actionlint"
if "$bin/actionlint" hardened/.github/workflows/label-pr.yml; then pass hardened-actionlint; else fail hardened-actionlint; fi

exit $status
