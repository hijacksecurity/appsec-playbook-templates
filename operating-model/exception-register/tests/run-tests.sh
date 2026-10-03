#!/usr/bin/env bash
# Valid fixtures must pass; every invalid fixture must fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
check=scripts/check-exceptions.sh
status=0
if "$check" tests/valid/exceptions > /dev/null; then echo "PASS valid"; else echo "FAIL valid (should pass)"; status=1; fi
for d in tests/invalid/*/; do
  name=$(basename "$d")
  if "$check" "$d/exceptions" > /dev/null; then echo "FAIL $name (should fail)"; status=1; else echo "PASS $name"; fi
done
exit $status
