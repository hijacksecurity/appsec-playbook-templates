#!/usr/bin/env bash
# Tests for the "are we affected?" schema and queries.
# Loads schema.sql and sample-data.sql into an in-memory SQLite database, runs each
# query in queries.sql on its own, and compares the exact rows with expected/<x>.txt.
# Needs: bash 3.2+, sqlite3, awk.
set -u
cd "$(dirname "$0")/.." || exit 1
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

# The text of query "(x)" from queries.sql: from its "-- (x)" line to the next one.
query() { awk -v id="$1" '/^-- \([a-z]\)/ { on = (index($0, "-- (" id ")") == 1) } on' queries.sql; }

# run SQL...: load the schema and sample data, then run the given SQL.
run() { { cat schema.sql sample-data.sql; printf '%s\n' "$@"; } | sqlite3 -bail -batch -header :memory: 2>&1; }

echo "== are-we-affected"
if out=$(run "SELECT 1;"); then
  pass "schema and sample data load"
else
  fail "schema and sample data load: $out"; exit 1
fi

for want in tests/expected/*.txt; do
  id=$(basename "$want" .txt)
  sql=$(query "$id")
  if [ -z "$sql" ]; then fail "query ($id) not found in queries.sql"; continue; fi
  out=$(run "$sql")
  if [ "$out" = "$(cat "$want")" ]; then pass "query ($id)"; else fail "query ($id)"; printf '%s\n' "$out" | diff "$want" - ; fi
done

# Every query in queries.sql must have an expected result.
while read -r id; do
  [ -f "tests/expected/$id.txt" ] || fail "query ($id) has no tests/expected/$id.txt"
done < <(grep -oE '^-- \([a-z]\)' queries.sql | sed 's/[^a-z]//g')

# rejects NAME SQL: the schema must refuse this insert.
rejects() {
  if run "$2" >/dev/null; then fail "$1 (was accepted)"; else pass "$1"; fi
}
cols="INSERT INTO assets (id, name, repo, tier, business, data_class, internet_facing, indirect, auth) VALUES"
rejects "payment data can't be Tier 2"      "$cols ('svc:x', 'x', 'pinecart/x', 2, 'customer-facing', 'payment', 0, 0, 'service');"
rejects "deploy rights can't be Tier 2"     "$cols ('svc:x', 'x', 'pinecart/x', 2, 'publish-or-deploy-rights', 'none', 0, 0, 'service');"
rejects "internet-facing can't be Tier 3"   "$cols ('svc:x', 'x', 'pinecart/x', 3, 'internal', 'none', 1, 0, 'staff');"
rejects "indirect exposure can't be Tier 3" "$cols ('svc:x', 'x', 'pinecart/x', 3, 'internal', 'none', 0, 1, 'service');"
rejects "unknown auth value"                "$cols ('svc:x', 'x', 'pinecart/x', 2, 'customer-facing', 'none', 1, 0, 'authenticated');"
rejects "resolved SHA must be 40 characters" \
  "INSERT INTO action_usages VALUES ('svc:search-api', 'ci.yml', 'actions/checkout', 'v4', 'abc123', '2026-09-14T00:00:00Z');"
if run "$cols ('svc:x', 'x', 'pinecart/x', 1, 'internal', 'none', 0, 0, 'staff');" >/dev/null; then
  pass "a tier can be stricter than the facts"
else
  fail "a tier can be stricter than the facts"
fi

exit $status
