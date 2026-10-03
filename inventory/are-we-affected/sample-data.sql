-- Sample data: six Pinecart services. Pinecart is fictional; so are these teams,
-- image digests (shortened), the action 'example-actions/changed-files' and its SHAs.
--
-- Planted for the queries:
--   * A compromised npm package: pkg:npm/axios at 1.14.1.
--   * A repointed action tag: example-actions/changed-files@v45 resolved to the
--     malicious commit bad0bad0... between 2026-09-14T09:00Z and 2026-09-15T16:00Z,
--     then the tag was restored to the good commit c0ffee00...

INSERT INTO assets (id, name, repo, owner_team, owner_source, owner_confidence, oncall,
                    tier, business, data_class, internet_facing, indirect, auth) VALUES
  ('svc:checkout-api',    'checkout-api',    'pinecart/checkout-api',    'checkout-team',   'catalog',    'high',   '#checkout-oncall',
   1, 'revenue-critical', 'payment',          1, 1, 'any-customer'),
  ('svc:storefront-api',  'storefront-api',  'pinecart/storefront-api',  'storefront-team', 'codeowners', 'medium', '#storefront-oncall',
   1, 'revenue-critical', 'none',             1, 1, 'anonymous'),
  -- Tier 1 because it stores bulk personal data, even though it is not on the checkout path.
  -- Nobody has claimed it: it belongs in the orphan queue.
  ('svc:order-history',   'order-history',   'pinecart/order-history',   NULL,              NULL,         'none',   NULL,
   1, 'customer-facing',  'bulk-personal',    0, 1, 'service'),
  ('svc:search-api',      'search-api',      'pinecart/search-api',      'search-team',     'catalog',    'high',   '#search-oncall',
   2, 'customer-facing',  'none',             1, 1, 'anonymous'),
  ('svc:recommendations', 'recommendations', 'pinecart/recommendations', NULL,              NULL,         'none',   NULL,
   2, 'customer-facing',  'limited-personal', 0, 1, 'service'),
  ('svc:ops-dashboard',   'ops-dashboard',   'pinecart/ops-dashboard',   'internal-tools',  'scm-team',   'low',    '#internal-tools',
   3, 'internal',         'none',             0, 0, 'staff');

-- SBOM contents per image. order-history's running image has no SBOM at all.
INSERT INTO components (asset_id, image_digest, purl, version, generation_context) VALUES
  ('svc:checkout-api',    'sha256:c0a1', 'pkg:npm/axios',   '1.14.1',  'post-build'),  -- compromised
  ('svc:checkout-api',    'sha256:c0a1', 'pkg:npm/express', '4.21.2',  'post-build'),
  ('svc:storefront-api',  'sha256:5f01', 'pkg:npm/axios',   '1.14.0',  'post-build'),  -- running in prod
  ('svc:storefront-api',  'sha256:5f02', 'pkg:npm/axios',   '1.14.1',  'post-build'),  -- compromised, staging only
  ('svc:search-api',      'sha256:5ea1', 'pkg:npm/axios',   '1.13.2',  'post-build'),
  ('svc:recommendations', 'sha256:7ec1', 'pkg:pypi/numpy',  '2.3.1',   'build'),
  ('svc:ops-dashboard',   'sha256:0d01', 'pkg:npm/axios',   '1.13.2',  'pre-build'),   -- running
  ('svc:ops-dashboard',   'sha256:0d02', 'pkg:npm/axios',   '1.14.1',  'pre-build');   -- compromised, built, not deployed

-- What is running, by digest.
INSERT INTO deployments (asset_id, cluster, namespace, image_digest, last_seen) VALUES
  ('svc:checkout-api',    'prod-eu',  'checkout',   'sha256:c0a1', '2026-10-01T08:00:00Z'),
  ('svc:checkout-api',    'prod-us',  'checkout',   'sha256:c0a1', '2026-10-01T08:00:00Z'),
  ('svc:storefront-api',  'prod-eu',  'storefront', 'sha256:5f01', '2026-10-01T08:00:00Z'),
  ('svc:storefront-api',  'staging',  'storefront', 'sha256:5f02', '2026-10-01T08:00:00Z'),
  ('svc:order-history',   'prod-eu',  'orders',     'sha256:04d1', '2026-10-01T08:00:00Z'),
  ('svc:search-api',      'prod-eu',  'search',     'sha256:5ea1', '2026-10-01T08:00:00Z'),
  ('svc:recommendations', 'prod-eu',  'recs',       'sha256:7ec1', '2026-10-01T08:00:00Z'),
  ('svc:ops-dashboard',   'internal', 'ops',        'sha256:0d01', '2026-10-01T08:00:00Z');

-- Action resolutions over time. Good commit: c0ffee00... Malicious: bad0bad0...
-- Pinned commit used by search-api: a1b2c3d4...
INSERT INTO action_usages (asset_id, workflow_path, action, ref_as_written, resolved_sha, observed_at) VALUES
  -- checkout-api ran twice inside the window. Before and after it, the tag resolved to the good commit.
  ('svc:checkout-api',    '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00', '2026-09-13T10:00:00Z'),
  ('svc:checkout-api',    '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'bad0bad0bad0bad0bad0bad0bad0bad0bad0bad0', '2026-09-14T11:20:00Z'),
  ('svc:checkout-api',    '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'bad0bad0bad0bad0bad0bad0bad0bad0bad0bad0', '2026-09-15T08:05:00Z'),
  ('svc:checkout-api',    '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00', '2026-09-16T09:00:00Z'),
  ('svc:storefront-api',  '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'bad0bad0bad0bad0bad0bad0bad0bad0bad0bad0', '2026-09-14T15:42:00Z'),
  -- Same tag, but this workflow did not run during the window.
  ('svc:storefront-api',  '.github/workflows/release.yml', 'example-actions/changed-files', 'v45', 'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00', '2026-09-12T17:00:00Z'),
  ('svc:storefront-api',  '.github/workflows/release.yml', 'example-actions/changed-files', 'v45', 'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00', '2026-09-17T17:00:00Z'),
  -- The orphan ran it too. The hit has nobody to route to.
  ('svc:order-history',   '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'bad0bad0bad0bad0bad0bad0bad0bad0bad0bad0', '2026-09-15T13:30:00Z'),
  -- Pinned by SHA: ran inside the window, but never resolved to the malicious commit.
  ('svc:search-api',      '.github/workflows/ci.yml',      'example-actions/changed-files', 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4',
                                                                                                 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4', '2026-09-14T12:00:00Z'),
  -- Ran only after the tag was restored.
  ('svc:recommendations', '.github/workflows/ci.yml',      'example-actions/changed-files', 'v45', 'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00', '2026-09-16T10:15:00Z'),
  -- Other actions, to show the query filters by action.
  ('svc:checkout-api',    '.github/workflows/ci.yml',      'actions/checkout', '3d3c42e5aac5ba805825da76410c181273ba90b1',
                                                                                   '3d3c42e5aac5ba805825da76410c181273ba90b1', '2026-09-14T11:20:00Z'),
  ('svc:ops-dashboard',   '.github/workflows/ci.yml',      'actions/checkout', 'v4', 'd00dd00dd00dd00dd00dd00dd00dd00dd00dd00d', '2026-09-14T13:00:00Z');
