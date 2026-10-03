#!/usr/bin/env bash
# Tests for the dependency-update settings.
# - renovate.json passes Renovate's own config validator, and a broken copy fails it.
# - dependabot.yml matches the Dependabot schema, and a broken copy fails it.
# - npm, with .npmrc: loads every setting, and a dependency's install script doesn't run.
# - pnpm, with pnpm-workspace.yaml: an unapproved install script fails the install;
#   once approved in allowBuilds, it runs.
# Needs Node.js 24+, npm, python3 with venv, jq, and network access (downloads the pinned
# tools from npm and PyPI).
set -u
cd "$(dirname "$0")/.." || exit 1
here=$PWD
fixture=$here/tests/fixtures/has-install-script

RENOVATE_VERSION=44.115.9
NPM_VERSION=12.1.0
PNPM_VERSION=11.28.0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }
# Our own rules while installing the test tools: no install scripts.
export npm_config_ignore_scripts=true npm_config_update_notifier=false npm_config_fund=false npm_config_audit=false

echo "== install pinned tools"
npm install --silent --no-save --prefix "$tmp/tools" \
  "renovate@$RENOVATE_VERSION" "npm@$NPM_VERSION" "pnpm@$PNPM_VERSION" || { echo "FAIL install"; exit 1; }
python3 -m venv "$tmp/venv"
"$tmp/venv/bin/pip" install --quiet --disable-pip-version-check --require-hashes --only-binary :all: \
  -r tests/requirements.txt || { echo "FAIL install check-jsonschema"; exit 1; }
validator=$tmp/tools/node_modules/.bin/renovate-config-validator
npm_bin=$tmp/tools/node_modules/.bin/npm
pnpm_bin=$tmp/tools/node_modules/.bin/pnpm
unset npm_config_ignore_scripts

echo "== renovate.json"
if "$validator" --strict renovate.json >"$tmp/out" 2>&1; then pass renovate-valid
else fail renovate-valid; sed 's/^/    /' "$tmp/out"; fi
jq '.minimumReleaseAge = "7 dayz" | .minimumReleaseAgeTypo = true' renovate.json > "$tmp/bad-renovate.json"
if "$validator" --strict "$tmp/bad-renovate.json" >/dev/null 2>&1; then fail renovate-broken-rejected
else pass renovate-broken-rejected; fi

echo "== dependabot.yml"
if "$tmp/venv/bin/check-jsonschema" --builtin-schema vendor.dependabot dependabot.yml >"$tmp/out" 2>&1; then
  pass dependabot-valid
else fail dependabot-valid; sed 's/^/    /' "$tmp/out"; fi
sed 's/default-days: 7/default-dayz: 7/' dependabot.yml > "$tmp/bad-dependabot.yml"
if "$tmp/venv/bin/check-jsonschema" --builtin-schema vendor.dependabot "$tmp/bad-dependabot.yml" >/dev/null 2>&1; then
  fail dependabot-broken-rejected
else pass dependabot-broken-rejected; fi

# project DIR: a project that depends on the fixture package, which has a postinstall script.
project() {
  mkdir -p "$1"
  printf '{ "name": "t", "version": "1.0.0", "private": true, "dependencies": { "has-install-script": "file:%s" } }\n' \
    "$fixture" > "$1/package.json"
}

echo "== npm $NPM_VERSION with .npmrc"
p=$tmp/npm-project; project "$p"; cp .npmrc "$p/.npmrc"
got=$(cd "$p" && "$npm_bin" config get min-release-age)/$(cd "$p" && "$npm_bin" config get ignore-scripts)/$(cd "$p" && "$npm_bin" config get allow-git)
if [ "$got" = "7/true/none" ]; then pass npmrc-loaded; else fail "npmrc-loaded (got $got)"; fi
# strict-npmrc turns unknown keys into errors, so these prove npm knows every key in .npmrc.
# (npm config commands skip the check, so use npm ls in a project with no dependencies.)
# strict_npmrc DIR NPMRC_TEXT: exit 0 if npm accepts the .npmrc.
strict_npmrc() {
  mkdir -p "$1" && printf '%s\n' "$2" > "$1/.npmrc" && echo '{ "name": "t", "version": "1.0.0" }' > "$1/package.json"
  (cd "$1" && npm_config_strict_npmrc=true "$npm_bin" ls >/dev/null 2>&1)
}
if strict_npmrc "$tmp/strict-ok" "$(cat .npmrc)"; then pass npmrc-all-keys-known; else fail npmrc-all-keys-known; fi
if strict_npmrc "$tmp/strict-typo" "min-release-agee=7"; then fail npmrc-unknown-key-rejected
else pass npmrc-unknown-key-rejected; fi
if (cd "$p" && MARKER_FILE="$tmp/npm-marker" "$npm_bin" install --silent >/dev/null 2>&1) && [ ! -e "$tmp/npm-marker" ]; then
  pass npm-install-script-blocked
else fail npm-install-script-blocked; fi
# Control: with scripts explicitly allowed, the same install does run the script.
rm -rf "$p/node_modules"
if (cd "$p" && MARKER_FILE="$tmp/npm-marker" "$npm_bin" install --silent --ignore-scripts=false \
      --dangerously-allow-all-scripts >/dev/null 2>&1) && [ -e "$tmp/npm-marker" ]; then
  pass npm-control-script-runs
else fail npm-control-script-runs; fi

echo "== pnpm $PNPM_VERSION with pnpm-workspace.yaml"
p=$tmp/pnpm-project; project "$p"; cp pnpm-workspace.yaml "$p/pnpm-workspace.yaml"
got=$(cd "$p" && "$pnpm_bin" config get minimumReleaseAge)
if [ "$got" = 10080 ]; then pass pnpm-settings-loaded; else fail "pnpm-settings-loaded (got $got)"; fi
if (cd "$p" && MARKER_FILE="$tmp/pnpm-marker" "$pnpm_bin" install >"$tmp/out" 2>&1); then
  fail "pnpm-unapproved-script-fails (install succeeded)"
elif [ -e "$tmp/pnpm-marker" ]; then fail "pnpm-unapproved-script-fails (script ran)"
elif ! grep -q ERR_PNPM_IGNORED_BUILDS "$tmp/out"; then fail "pnpm-unapproved-script-fails (wrong error)"; sed 's/^/    /' "$tmp/out"
else pass pnpm-unapproved-script-fails; fi
# A local (file:) package is approved by name plus path, like a git dependency.
key="has-install-script@file:$(realpath --relative-to="$p" "$fixture")"
sed "s|^allowBuilds: {}\$|allowBuilds:\n  '$key': true|" pnpm-workspace.yaml > "$p/pnpm-workspace.yaml"
rm -rf "$p/node_modules"
if (cd "$p" && MARKER_FILE="$tmp/pnpm-marker" "$pnpm_bin" install >"$tmp/out" 2>&1) && [ -e "$tmp/pnpm-marker" ]; then
  pass pnpm-approved-script-runs
else fail pnpm-approved-script-runs; sed 's/^/    /' "$tmp/out"; fi

exit $status
