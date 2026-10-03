#!/usr/bin/env bash
# Lists every third-party GitHub Action used across a folder of cloned repos.
# Usage: list-actions.sh [--unpinned-only] REPOS_DIR
#   REPOS_DIR holds one subfolder per cloned repo.
#   Scans .github/workflows/*.yml|*.yaml and every action.yml|action.yaml (composite actions).
#   --unpinned-only prints only references that are not pinned (pinned is "no" or "docker-tag").
# Output: tab-separated, with a header row: repo, file, action, ref, pinned
#   pinned: yes            the ref is a full 40-character commit SHA
#           no             a tag, a branch, a short SHA, or no ref at all
#           docker-digest  a docker:// image pinned by sha256 digest
#           docker-tag     a docker:// image by tag (mutable)
# Local actions (./path) are skipped. Quotes and trailing comments are removed.
# This is a first pass: refs as written. It does not resolve tags to commits.
# Needs: bash 3.2+ and standard find, sort, awk. Works on macOS and Linux.
set -eu

usage() { echo "usage: $(basename "$0") [--unpinned-only] REPOS_DIR" >&2; exit 2; }

unpinned_only=0
if [ "${1:-}" = "--unpinned-only" ]; then unpinned_only=1; shift; fi
[ $# -eq 1 ] || usage
dir=${1%/}
if [ ! -d "$dir" ]; then echo "error: no such folder: $dir" >&2; exit 2; fi

printf 'repo\tfile\taction\tref\tpinned\n'

# Files to scan in one repo, relative to the repo root, sorted the same way everywhere.
files_in() {
  (
    cd "$1" || exit 1
    if [ -d .github/workflows ]; then
      find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \)
    fi
    find . -path ./.git -prune -o -type f \( -name action.yml -o -name action.yaml \) -print \
      | sed 's|^\./||'
  ) | LC_ALL=C sort -u
}

for repo_path in "$dir"/*/; do
  [ -d "$repo_path" ] || continue
  repo=$(basename "$repo_path")
  files_in "$repo_path" | while IFS= read -r file; do
    awk -v repo="$repo" -v file="$file" -v unpinned_only="$unpinned_only" '
      # Only "uses:" keys, as a step ("- uses:") or a job calling a reusable workflow.
      /^[[:space:]]*(-[[:space:]]+)?uses:/ {
        v = $0
        sub(/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*/, "", v)
        sub(/[[:space:]]+#.*$/, "", v)     # trailing comment, e.g. "# v4.2.0"
        gsub(/["\047]/, "", v)             # double and single quotes
        sub(/[[:space:]]+$/, "", v)
        if (v == "" || v ~ /^\.\//) next   # empty, or a local action in this repo

        if (v ~ /^docker:\/\//) {
          at = index(v, "@")
          if (at > 0) {
            action = substr(v, 1, at - 1); ref = substr(v, at + 1)
            pinned = (ref ~ /^sha256:/ && length(ref) == 71 && substr(ref, 8) !~ /[^0-9a-f]/) ? "docker-digest" : "docker-tag"
          } else {
            # A tag follows the last ":" after the last "/" (a registry port is not a tag).
            action = v; ref = ""; pinned = "docker-tag"
            n = split(v, parts, "/"); last = parts[n]; c = index(last, ":")
            if (c > 0) { ref = substr(last, c + 1); action = substr(v, 1, length(v) - length(last) + c - 1) }
          }
        } else {
          # owner/repo[/path]@ref. Split at the last "@".
          action = v; ref = ""
          if (match(v, /@[^@]*$/)) { action = substr(v, 1, RSTART - 1); ref = substr(v, RSTART + 1) }
          pinned = (length(ref) == 40 && ref !~ /[^0-9a-f]/) ? "yes" : "no"
        }
        if (unpinned_only == 1 && (pinned == "yes" || pinned == "docker-digest")) next
        printf "%s\t%s\t%s\t%s\t%s\n", repo, file, action, ref, pinned
      }
    ' "$repo_path$file"
  done
done
