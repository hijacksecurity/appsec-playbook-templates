# Inventory (3.2)

Templates and working examples for **3.2 See Everything** in The AppSec Program Playbook:
know what exists, who owns it, how critical it is, and where it runs. The test of an
inventory is one question: *"Are we affected by package X or action Y? Where, since when,
and who owns it?"* These pieces help you answer it in minutes.

| Piece | What it is | Post section |
|---|---|---|
| [`catalog-info.template.yaml`](catalog-info.template.yaml) | One file per repo: owner, tier, data class and exposure. A Backstage Component, but it works without Backstage too | Step 3 (ownership) and the catalog example in the demo |
| [`tiering-rubric.md`](tiering-rubric.md) | One page: Tier 1, 2 and 3 rules, sensitive data defined once, and how the tier maps to 3.4's impact tier | Step 4 (tier by criticality) |
| [`asset-record.template.yaml`](asset-record.template.yaml) | The minimum fields to keep for every asset, on every layer | Step 1 (minimum data model) and Takeaways |
| [`scripts/list-actions.sh`](scripts/list-actions.sh) | Lists every third-party GitHub Action across a folder of cloned repos, and whether each one is pinned to a full commit SHA | Step 6 (actions) and the workflow inventory one-liner in the demo |
| [`are-we-affected/`](are-we-affected/) | A small SQLite inventory with Pinecart sample data and the "are we affected?" queries | Step 7 (the acceptance test) |

## Try it in 5 minutes

You need `bash`, `awk` and `sqlite3`. All three come with macOS and with Ubuntu (on Ubuntu,
`sudo apt-get install sqlite3` if it's missing).

**1. List the actions your repos use.** Clone your org's repos into one folder (one
subfolder per repo), then:

```bash
inventory/scripts/list-actions.sh path/to/repos > actions.tsv
inventory/scripts/list-actions.sh --unpinned-only path/to/repos   # just the ones to fix
```

The output is tab-separated, with a header: `repo`, `file`, `action`, `ref`, `pinned`.

| `pinned` | Means |
|---|---|
| `yes` | The ref is a full 40-character commit SHA |
| `no` | A tag, a branch, a short SHA, or no ref |
| `docker-digest` | A `docker://` image pinned by `sha256` digest |
| `docker-tag` | A `docker://` image by tag, which can change |

It scans `.github/workflows/*.yml` and `*.yaml`, plus every `action.yml` and `action.yaml`
in the repo (composite actions). It skips local actions (`./path`), and removes quotes and
trailing comments. Pipe it into `cut -f3 | sort | uniq -c | sort -rn` for the most used
actions.

**2. Run the "are we affected?" queries on the sample data.**

```bash
cd inventory/are-we-affected
cat schema.sql sample-data.sql queries.sql | sqlite3 -header -column :memory:
```

You'll see:

- **(a)** which services ship the compromised `pkg:npm/axios@1.14.1`, with owner, tier,
  3.4 impact tier and where each one runs (one only in staging, one built but not running);
- **(b)** which repos ran `example-actions/changed-files` at the malicious commit during
  the exposure window. Today every `v45` tag resolves to the good commit, so only the
  timestamped history finds the three hits;
- **(c)** Tier 1 assets with no owner (one of them is also a hit in (b));
- **(d)** running services with no SBOM, reported as *unknown* instead of "not affected".

**3. Make it yours.** Copy `catalog-info.template.yaml` into a repo as `catalog-info.yaml`
and fill it in using `tiering-rubric.md`. Load your own data into `schema.sql`'s four tables
and change the package, action, SHA and window in `queries.sql`.

## What's real and what's made up

Pinecart is fictional. So are the teams, the image digests (shortened), the action
`example-actions/changed-files` and its SHAs. The shape of the planted incident follows
the real tag-repointing attacks described in the post.

## Limits

- `list-actions.sh` reads refs as written. It doesn't resolve tags to commits, so it can't
  tell you what ran during an incident window. Record resolved SHAs over time for that
  (the `action_usages` table shows the shape).
- It reads YAML line by line. A line inside a `run: |` block that starts with `uses:` would
  be listed by mistake.
- The SQL schema is the smallest one that answers the queries. The post adds triggers,
  token permissions, secrets, IaC modules, base images and more.

## Tests

```bash
inventory/scripts/tests/run-tests.sh
inventory/are-we-affected/tests/run-tests.sh
```

Both run offline and need only bash 3.2 or later, `awk` and `sqlite3`, so they run on
macOS and on Linux.

- `list-actions.sh` runs against fake repos in
  [`scripts/tests/fixtures/repos/`](scripts/tests/fixtures/repos/), and the output must
  match [`scripts/tests/expected/`](scripts/tests/expected/) exactly.
- The SQL tests load everything into an in-memory database, run each query on its own,
  and compare the exact rows with
  [`are-we-affected/tests/expected/`](are-we-affected/tests/expected/). They also check
  that the schema refuses a tier looser than the facts (payment data at Tier 2, an
  internet-facing service at Tier 3) and an `auth` value outside the four allowed.
