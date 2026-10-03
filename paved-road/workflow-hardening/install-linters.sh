#!/usr/bin/env bash
# Installs zizmor and actionlint at pinned versions into DIR/bin, checking each download
# against the SHA-256 below. Linux only (x86_64 and arm64).
# Usage: install-linters.sh DIR
set -euo pipefail

ZIZMOR_VERSION=1.30.1
ZIZMOR_SHA256_X64=e65324f4430c2717591937edcec90ccbefaf14c174f8ec9415e03ca875b46e1a
ZIZMOR_SHA256_ARM64=7ff1dce33bdd18fd2a4affe63bdd47efcccca97b2cec1c1863ec26e9e2647540

ACTIONLINT_VERSION=1.7.12
ACTIONLINT_SHA256_X64=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
ACTIONLINT_SHA256_ARM64=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6

if [ $# -ne 1 ]; then echo "usage: install-linters.sh DIR" >&2; exit 2; fi
dir=$1
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)        z_arch=x86_64;  a_arch=amd64; z_sum=$ZIZMOR_SHA256_X64;   a_sum=$ACTIONLINT_SHA256_X64 ;;
  Linux/aarch64|Linux/arm64) z_arch=aarch64; a_arch=arm64; z_sum=$ZIZMOR_SHA256_ARM64; a_sum=$ACTIONLINT_SHA256_ARM64 ;;
  *) echo "install-linters.sh: only Linux x86_64 and arm64 are supported" >&2; exit 2 ;;
esac

mkdir -p "$dir/bin"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# fetch URL FILE SHA256: download, then refuse the file unless the checksum matches.
fetch() {
  curl -sSfL --retry 3 --proto '=https' -o "$2" "$1"
  echo "$3  $2" | sha256sum --check --strict --quiet || {
    echo "install-linters.sh: checksum mismatch for $1" >&2
    exit 1
  }
}

f=zizmor-${z_arch}-unknown-linux-gnu.tar.gz
fetch "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/$f" "$tmp/$f" "$z_sum"
tar -xzf "$tmp/$f" -C "$tmp" zizmor
install -m 0755 "$tmp/zizmor" "$dir/bin/zizmor"

f=actionlint_${ACTIONLINT_VERSION}_linux_${a_arch}.tar.gz
fetch "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/$f" "$tmp/$f" "$a_sum"
tar -xzf "$tmp/$f" -C "$tmp" actionlint
install -m 0755 "$tmp/actionlint" "$dir/bin/actionlint"

"$dir/bin/zizmor" --version
"$dir/bin/actionlint" -version | head -1
