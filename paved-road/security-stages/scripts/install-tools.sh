#!/usr/bin/env bash
# Installs gitleaks, osv-scanner and semgrep at pinned versions into TOOLS_DIR.
# Every download is checked against a SHA-256 written in this file (or, for semgrep and
# its Python dependencies, in semgrep-requirements.txt). A mismatch stops the install.
# Linux only (x86_64 and arm64), which covers GitHub-hosted Ubuntu runners.
#
# Usage: install-tools.sh TOOLS_DIR [secrets|sca|sast ...]
#   With no stage names it installs all three tools.
set -euo pipefail

GITLEAKS_VERSION=8.30.1
GITLEAKS_SHA256_X64=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
GITLEAKS_SHA256_ARM64=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080

OSV_SCANNER_VERSION=2.6.0
OSV_SCANNER_SHA256_X64=ca69b3d3cd08f889a49dc0a383122f71cc528b83803671df5fd874d97485b108
OSV_SCANNER_SHA256_ARM64=2c71403eb443d05891c4f268c3ad771cf4f16e5443463fd7851ef8f454d3c7e4

# The semgrep version is pinned in semgrep-requirements.txt, with hashes for every package.

if [ $# -lt 1 ]; then
  echo "usage: install-tools.sh TOOLS_DIR [secrets|sca|sast ...]" >&2
  exit 2
fi
tools_dir=$1; shift
stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(secrets sca sast)
here=$(cd "$(dirname "$0")/.." && pwd)

if [ "$(uname -s)" != Linux ]; then
  echo "install-tools.sh: only Linux runners are supported" >&2
  exit 2
fi
case "$(uname -m)" in
  x86_64)        gl_arch=x64;   osv_arch=amd64; gl_sum=$GITLEAKS_SHA256_X64;   osv_sum=$OSV_SCANNER_SHA256_X64 ;;
  aarch64|arm64) gl_arch=arm64; osv_arch=arm64; gl_sum=$GITLEAKS_SHA256_ARM64; osv_sum=$OSV_SCANNER_SHA256_ARM64 ;;
  *) echo "install-tools.sh: unsupported CPU $(uname -m)" >&2; exit 2 ;;
esac

mkdir -p "$tools_dir/bin"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# fetch URL FILE SHA256: download, then refuse the file unless the checksum matches.
fetch() {
  curl -sSfL --retry 3 --proto '=https' -o "$2" "$1"
  echo "$3  $2" | sha256sum --check --strict --quiet || {
    echo "install-tools.sh: checksum mismatch for $1" >&2
    exit 1
  }
}

for stage in "${stages[@]}"; do
  case "$stage" in
    secrets)
      if [ "$("$tools_dir/bin/gitleaks" version 2>/dev/null || true)" = "$GITLEAKS_VERSION" ]; then continue; fi
      f=gitleaks_${GITLEAKS_VERSION}_linux_${gl_arch}.tar.gz
      fetch "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/$f" "$tmp/$f" "$gl_sum"
      tar -xzf "$tmp/$f" -C "$tmp" gitleaks
      install -m 0755 "$tmp/gitleaks" "$tools_dir/bin/gitleaks"
      ;;
    sca)
      if "$tools_dir/bin/osv-scanner" --version 2>/dev/null | grep -q "version: $OSV_SCANNER_VERSION\$"; then continue; fi
      fetch "https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_linux_${osv_arch}" \
        "$tmp/osv-scanner" "$osv_sum"
      install -m 0755 "$tmp/osv-scanner" "$tools_dir/bin/osv-scanner"
      ;;
    sast)
      want=$(sed -n 's/^semgrep==\([0-9.]*\).*/\1/p' "$here/semgrep-requirements.txt")
      if [ "$("$tools_dir/semgrep-venv/bin/semgrep" --version 2>/dev/null || true)" = "$want" ]; then continue; fi
      rm -rf "$tools_dir/semgrep-venv"
      python3 -m venv "$tools_dir/semgrep-venv"
      # --require-hashes: pip refuses any package, direct or transitive, without a matching hash.
      "$tools_dir/semgrep-venv/bin/pip" install --quiet --disable-pip-version-check \
        --require-hashes --only-binary :all: -r "$here/semgrep-requirements.txt"
      ln -sf "$tools_dir/semgrep-venv/bin/semgrep" "$tools_dir/bin/semgrep"
      ;;
    *) echo "install-tools.sh: unknown stage '$stage'" >&2; exit 2 ;;
  esac
done
