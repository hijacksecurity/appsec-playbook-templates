#!/usr/bin/env bash
# Checks exception files.
# Usage: check-exceptions.sh [--report FILE] [PATH...]
#   PATH is an exception file or a folder to search. The default is the whole exceptions/ folder.
#   On a pull request, pass only the changed files. On the scheduled run, pass nothing.
#   --report FILE writes a Markdown list of the problems (used to open an issue).
# Exits non-zero if any exception is invalid, expired, too long, misfiled, or for a KEV finding.
# Needs: bash 4+, yq (mikefarah, v4), GNU date. All are preinstalled on GitHub's ubuntu runners.
set -euo pipefail

report=/dev/null
if [[ "${1:-}" == "--report" ]]; then report="$2"; shift 2; fi
(( $# > 0 )) || set -- exceptions
: > "$report"

# Maximum days per grant, by priority (see the policy in 3.1 of The AppSec Program Playbook).
declare -A max_days=([p1]=14 [p2]=30 [p3]=90 [p4]=180 [hygiene]=180)
today=$(date -u +%F)
failures=0

err() {
  failures=$((failures + 1))
  echo "::error file=$1::$2"
  echo "- \`$1\`: $2" >> "$report"
}

# The value of a field, or "" if it is missing or empty.
field() { yq ".$2 // \"\"" "$1" 2>/dev/null || true; }

check() {
  local f=$1 folder prio key name
  folder=$(basename "$(dirname "$f")")
  prio=$(field "$f" priority)
  key=${prio,,}

  # Every exception needs these.
  for name in id owner priority justification accepted_by approved_on expires; do
    if [[ -z "$(field "$f" "$name")" ]]; then err "$f" "missing required field '$name'"; fi
  done

  if [[ "$key" == "p0" ]]; then err "$f" "P0 (leaked live secret) can never be excepted"; return; fi
  if [[ ! -v "max_days[$key]" ]]; then err "$f" "unknown priority '$prio'"; return; fi
  if [[ "$key" != "${folder,,}" ]]; then err "$f" "priority $prio does not match folder $folder/"; return; fi
  if [[ "$(yq '.kev' "$f")" == "true" ]]; then
    err "$f" "KEV findings can't be excepted: apply CISA's required action or isolate the asset"; return
  fi

  # P1-P4 need a security review. For hygiene, AppSec is only informed.
  if [[ "$key" != "hygiene" && -z "$(field "$f" security_review)" ]]; then
    err "$f" "missing required field 'security_review'"
  fi

  # P1-P3 need a verified control that removes a precondition of the exploit.
  if [[ "$key" == p[123] ]]; then
    for name in type description verified_by evidence; do
      if [[ -z "$(field "$f" "compensating_control.$name")" ]]; then
        err "$f" "$prio needs 'compensating_control.$name'"
      fi
    done
    local type
    type=$(field "$f" compensating_control.type)
    if [[ "$type" == "filter" ]]; then
      err "$f" "a filter (WAF rule, virtual patch) can't back an exception; remove a precondition instead"
    elif [[ -n "$type" && "$type" != "precondition-removed" ]]; then
      err "$f" "compensating_control.type must be 'precondition-removed', not '$type'"
    fi
  fi

  local approved expires a e days
  approved=$(field "$f" approved_on); expires=$(field "$f" expires)
  if ! a=$(date -ud "$approved" +%s 2>/dev/null) || ! e=$(date -ud "$expires" +%s 2>/dev/null); then
    err "$f" "approved_on and expires must be dates (YYYY-MM-DD)"; return
  fi
  days=$(( (e - a) / 86400 ))
  if (( days > max_days[$key] )); then err "$f" "$prio granted for $days days (max ${max_days[$key]})"; fi
  if [[ "$expires" < "$today" ]]; then err "$f" "expired on $expires; owner $(field "$f" owner) must fix or renew"; fi
}

shopt -s nullglob globstar
for path in "$@"; do
  if [[ -d "$path" ]]; then
    for f in "$path"/**/*.yaml "$path"/**/*.yml; do check "$f"; done
  elif [[ -f "$path" ]]; then
    check "$path"
  else
    err "$path" "no such file or folder"
  fi
done

if (( failures > 0 )); then
  echo "$failures problem(s) found."
  exit 1
fi
echo "All exceptions are valid."
