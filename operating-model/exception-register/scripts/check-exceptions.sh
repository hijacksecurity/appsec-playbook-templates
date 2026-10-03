#!/usr/bin/env bash
# Checks every exception file under an exceptions/ folder.
# Usage: check-exceptions.sh [exceptions-dir] [report-file]
# Exits non-zero if any exception is invalid, expired, too long, misfiled, or for a KEV finding.
# Needs: bash 4+, yq (mikefarah, v4), GNU date. All are preinstalled on GitHub's ubuntu runners.
set -euo pipefail

dir="${1:-exceptions}"
report="${2:-/dev/null}"
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

shopt -s nullglob globstar
for f in "$dir"/**/*.yaml "$dir"/**/*.yml; do
  folder=$(basename "$(dirname "$f")")
  prio=$(yq '.priority' "$f")
  key=${prio,,}

  for field in id owner priority accepted_by security_review approved_on expires; do
    if [[ "$(yq ".$field" "$f")" == "null" ]]; then err "$f" "missing required field '$field'"; fi
  done

  if [[ "$key" == "p0" ]]; then err "$f" "P0 (leaked live secret) can never be excepted"; continue; fi
  if [[ ! -v "max_days[$key]" ]]; then err "$f" "unknown priority '$prio'"; continue; fi
  if [[ "$key" != "${folder,,}" ]]; then err "$f" "priority $prio does not match folder $folder/"; continue; fi
  if [[ "$(yq '.kev' "$f")" == "true" ]]; then
    err "$f" "KEV findings can't be excepted: apply CISA's required action or isolate the asset"; continue
  fi

  approved=$(yq '.approved_on' "$f"); expires=$(yq '.expires' "$f")
  if ! a=$(date -ud "$approved" +%s 2>/dev/null) || ! e=$(date -ud "$expires" +%s 2>/dev/null); then
    err "$f" "approved_on and expires must be dates (YYYY-MM-DD)"; continue
  fi
  days=$(( (e - a) / 86400 ))
  if (( days > max_days[$key] )); then err "$f" "$prio granted for $days days (max ${max_days[$key]})"; fi
  if [[ "$expires" < "$today" ]]; then err "$f" "expired on $expires; owner $(yq '.owner' "$f") must fix or renew"; fi
done

if (( failures > 0 )); then
  echo "$failures problem(s) found."
  exit 1
fi
echo "All exceptions are valid."
