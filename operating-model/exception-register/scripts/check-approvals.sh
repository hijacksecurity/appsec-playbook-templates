#!/usr/bin/env bash
# Checks that a pull request has the approvals the policy needs. For each priority folder the
# PR touches, it needs one approval from the risk-acceptor team AND one from the security-review
# team, from two different people. CODEOWNERS alone can't do this: it accepts any one owner.
#
# Usage in CI:
#   check-approvals.sh
#   Env: GH_TOKEN (must be able to read org teams), GH_REPO (owner/repo), PR_NUMBER, ORG,
#        APPROVERS_FILE (default: approvers.yaml)
# Usage offline (for tests), with no API calls:
#   check-approvals.sh --decide APPROVERS_FILE REVIEWS_JSON MEMBERS_JSON HEAD_SHA [FOLDER...]
#   REVIEWS_JSON: the GitHub "list reviews" response (user.login, state, commit_id, submitted_at).
#   MEMBERS_JSON: {"team-slug": ["login", ...], ...}
# Needs: bash 4+, yq (mikefarah, v4), and gh in CI.
set -euo pipefail

# Logins whose latest review approves HEAD_SHA. A later "changes requested" or a dismissal cancels
# an approval, and an approval of an older commit doesn't count. Comments don't change the state.
approvers() {
  HEAD_SHA="$2" yq -p json -o yaml '
    [.[] | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED")]
    | sort_by(.submitted_at) | group_by(.user.login) | map(.[-1])
    | map(select(.state == "APPROVED" and .commit_id == env(HEAD_SHA)) | .user.login) | .[]' "$1"
}

in_team() { # MEMBERS_JSON TEAM LOGIN
  [[ "$(TEAM="$2" LOGIN="$3" yq -p json '(.[env(TEAM)] // []) | any_c(. == env(LOGIN))' "$1")" == "true" ]]
}

# team CONFIG FOLDER ROLE -> team slug, or "" if the folder isn't in the config
team() { FOLDER="$2" yq ".[env(FOLDER)].$3 // \"\"" "$1"; }

decide() {
  local config=$1 reviews=$2 members=$3 head=$4; shift 4
  local -a who; mapfile -t who < <(approvers "$reviews" "$head")
  local failures=0 folder acceptor security login
  local -A acc sec both
  for folder in "$@"; do
    acceptor=$(team "$config" "$folder" acceptor)
    security=$(team "$config" "$folder" security)
    if [[ -z "$acceptor" || -z "$security" ]]; then
      echo "::error::exceptions/$folder/ has no approvers in $config"; failures=$((failures + 1)); continue
    fi
    acc=() sec=() both=()
    for login in "${who[@]}"; do
      if in_team "$members" "$acceptor" "$login"; then acc[$login]=1; both[$login]=1; fi
      if [[ "$security" != "none" ]] && in_team "$members" "$security" "$login"; then sec[$login]=1; both[$login]=1; fi
    done
    if (( ${#acc[@]} == 0 )); then
      echo "::error::exceptions/$folder/ needs an approval from @$acceptor (accepts the risk)"; failures=$((failures + 1))
    fi
    if [[ "$security" != "none" ]]; then
      if (( ${#sec[@]} == 0 )); then
        echo "::error::exceptions/$folder/ needs an approval from @$security (security review)"; failures=$((failures + 1))
      elif (( ${#acc[@]} > 0 && ${#both[@]} < 2 )); then
        echo "::error::exceptions/$folder/ needs two different people: one from @$acceptor and one from @$security"
        failures=$((failures + 1))
      fi
    fi
  done
  if (( failures > 0 )); then return 1; fi
  echo "Approvals are complete for: ${*:-no exception folders changed}"
}

if [[ "${1:-}" == "--decide" ]]; then shift; decide "$@"; exit; fi

: "${GH_REPO:?}" "${PR_NUMBER:?}" "${ORG:?}"
config=${APPROVERS_FILE:-approvers.yaml}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Priority folders touched by the PR. A renamed file counts for its old and new folder.
# Deleting a file (the fix shipped) needs only normal review, so removed files don't count.
mapfile -t folders < <(
  gh api --paginate "repos/$GH_REPO/pulls/$PR_NUMBER/files" \
    --jq '.[] | select(.status != "removed") | .filename, (.previous_filename // empty)' \
  | awk -F/ '$1 == "exceptions" && NF >= 3 { print $2 }' | sort -u)

head=$(gh api "repos/$GH_REPO/pulls/$PR_NUMBER" --jq '.head.sha')
gh api --paginate --slurp "repos/$GH_REPO/pulls/$PR_NUMBER/reviews" | yq -p json -o json 'flatten(1)' > "$work/reviews.json"
mapfile -t who < <(approvers "$work/reviews.json" "$head")

# Team membership of each approver, for the teams this PR needs.
mapfile -t teams < <(for folder in "${folders[@]}"; do
  team "$config" "$folder" acceptor; team "$config" "$folder" security
done | grep -vx -e '' -e none | sort -u)
echo '{}' > "$work/members.json"
for t in "${teams[@]}"; do
  # Fail loudly if the token can't see the team; otherwise every check would just say "needs approval".
  if ! gh api "orgs/$ORG/teams/$t" --silent; then
    echo "::error::can't read team @$ORG/$t. Does the token have read access to org members (read:org)?"; exit 1
  fi
  for login in "${who[@]}"; do
    state=$(gh api "orgs/$ORG/teams/$t/memberships/$login" --jq '.state' 2>/dev/null || true)
    if [[ "$state" == "active" ]]; then
      TEAM="$t" LOGIN="$login" yq -i -p json -o json '.[env(TEAM)] += [env(LOGIN)]' "$work/members.json"
    fi
  done
done

decide "$config" "$work/reviews.json" "$work/members.json" "$head" "${folders[@]}"
