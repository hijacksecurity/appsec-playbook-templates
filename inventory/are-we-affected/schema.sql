-- A minimal "are we affected?" inventory, in SQLite.
-- Four tables: what exists (assets), what is inside it (components),
-- where it runs (deployments), and which actions its CI ran (action_usages).
-- Field names and values match 3.2 and 3.4 of The AppSec Program Playbook.

PRAGMA foreign_keys = ON;

-- One row per service. Owner and tier live here, so every query can join them.
CREATE TABLE assets (
  id               TEXT PRIMARY KEY,               -- stable, never reused, e.g. 'svc:checkout-api'
  name             TEXT NOT NULL,
  repo             TEXT NOT NULL UNIQUE,           -- e.g. 'pinecart/checkout-api'
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'dormant', 'archived', 'decommissioned')),
  owner_team       TEXT,                           -- a team, never a person; NULL = orphan
  owner_source     TEXT CHECK (owner_source IN ('catalog', 'codeowners', 'deploy-metadata',
                                                'scm-team', 'commit-heuristic', 'default')),
  owner_confidence TEXT NOT NULL DEFAULT 'none'
                   CHECK (owner_confidence IN ('high', 'medium', 'low', 'none')),
  oncall           TEXT,                           -- where findings are routed, e.g. '#checkout-oncall'
  tier             INTEGER NOT NULL CHECK (tier IN (1, 2, 3)),
  business         TEXT NOT NULL CHECK (business IN ('revenue-critical', 'publish-or-deploy-rights',
                                                     'customer-facing', 'internal')),
  data_class       TEXT NOT NULL CHECK (data_class IN ('payment', 'credentials', 'bulk-personal',
                                                       'limited-personal', 'none')),
  internet_facing  INTEGER NOT NULL CHECK (internet_facing IN (0, 1)),
  indirect         INTEGER NOT NULL CHECK (indirect IN (0, 1)),  -- internet data reaches it
  auth             TEXT NOT NULL CHECK (auth IN ('anonymous', 'any-customer', 'staff', 'service')),
  -- The worst axis wins. The tier can be stricter than the facts, never looser.
  CHECK (tier = 1 OR (business NOT IN ('revenue-critical', 'publish-or-deploy-rights')
                      AND data_class NOT IN ('payment', 'credentials', 'bulk-personal'))),
  CHECK (tier <= 2 OR (business = 'internal' AND data_class = 'none'
                       AND internet_facing = 0 AND indirect = 0))
);

-- One row per package inside an image, from that image's SBOM.
-- purl is the package without a version ('pkg:npm/axios'); the version is its own column.
CREATE TABLE components (
  asset_id           TEXT NOT NULL REFERENCES assets(id),
  image_digest       TEXT NOT NULL,                -- the image the SBOM describes
  purl               TEXT NOT NULL,
  version            TEXT NOT NULL,
  generation_context TEXT NOT NULL CHECK (generation_context IN ('pre-build', 'build', 'post-build')),
  PRIMARY KEY (image_digest, purl, version)
);

-- What is running now, by image digest. Replaced on every sync from the cluster API.
CREATE TABLE deployments (
  asset_id     TEXT NOT NULL REFERENCES assets(id),
  cluster      TEXT NOT NULL,                      -- e.g. 'prod-eu'
  namespace    TEXT NOT NULL,
  image_digest TEXT NOT NULL,
  last_seen    TEXT NOT NULL,                      -- UTC, 'YYYY-MM-DDTHH:MM:SSZ'
  PRIMARY KEY (cluster, namespace, asset_id)
);

-- One row per workflow run (or per change) for each action reference.
-- Keep the history: a repointed tag is usually restored after an incident,
-- so only the timestamped resolved SHA shows what really ran.
CREATE TABLE action_usages (
  asset_id       TEXT NOT NULL REFERENCES assets(id),
  workflow_path  TEXT NOT NULL,                    -- e.g. '.github/workflows/ci.yml'
  action         TEXT NOT NULL,                    -- e.g. 'actions/checkout'
  ref_as_written TEXT NOT NULL,                    -- 'v4', 'main' or a SHA
  resolved_sha   TEXT NOT NULL CHECK (length(resolved_sha) = 40),
  observed_at    TEXT NOT NULL                     -- UTC, 'YYYY-MM-DDTHH:MM:SSZ'
);

CREATE INDEX components_by_package ON components (purl, version);
CREATE INDEX usages_by_action      ON action_usages (action, resolved_sha, observed_at);
