-- "Are we affected?" queries. Load schema.sql and your data first.
-- The pattern for every layer: match the indicator, walk to what is running,
-- join owner and tier, and sort the most critical and most exposed first.
-- impact_tier is the 3.4 starting impact tier for the asset's tier (1 top, 2 middle, 3 low).
-- Each query starts with a "-- (x)" line. The tests run them one at a time.

-- (a) Which services ship package X at version Y, who owns them, and where do they run?
--     Replace the purl and version with the ones from the advisory.
--     "not running" means an image has it but no deployment uses that image (yet).
SELECT a.name,
       a.tier,
       CASE a.tier WHEN 1 THEN 'top' WHEN 2 THEN 'middle' ELSE 'low' END AS impact_tier,
       COALESCE(a.owner_team, '(no owner)')                               AS owner,
       COALESCE(a.oncall, '-')                                            AS oncall,
       c.purl || '@' || c.version                                         AS package,
       c.image_digest,
       COALESCE(d.cluster || '/' || d.namespace, 'not running')           AS running_in,
       a.internet_facing,
       a.indirect,
       a.auth
FROM   components c
JOIN   assets a           ON a.id = c.asset_id
LEFT JOIN deployments d   ON d.image_digest = c.image_digest
WHERE  c.purl = 'pkg:npm/axios'
  AND  c.version = '1.14.1'
ORDER  BY a.tier, a.internet_facing DESC, a.indirect DESC, a.name, running_in;

-- (b) Which repos ran action A at a malicious commit during the exposure window?
--     Match the resolved SHA inside the window, never the tag: the tag is usually
--     restored after the incident, so today it looks clean.
SELECT a.repo,
       u.workflow_path,
       u.ref_as_written,
       MIN(u.observed_at)                    AS first_run,
       MAX(u.observed_at)                    AS last_run,
       COUNT(*)                              AS runs,
       a.tier,
       COALESCE(a.owner_team, '(no owner)')  AS owner,
       COALESCE(a.oncall, '-')               AS oncall
FROM   action_usages u
JOIN   assets a ON a.id = u.asset_id
WHERE  u.action = 'example-actions/changed-files'
  AND  u.resolved_sha = 'bad0bad0bad0bad0bad0bad0bad0bad0bad0bad0'
  AND  u.observed_at BETWEEN '2026-09-14T09:00:00Z' AND '2026-09-15T16:00:00Z'
GROUP  BY a.repo, u.workflow_path, u.ref_as_written
ORDER  BY a.tier, a.repo, u.workflow_path;

-- (c) Tier 1 assets with no owner. Each one goes to the default owner with a deadline
--     to claim it, reassign it, or schedule it for archive.
SELECT a.id,
       a.repo,
       a.data_class,
       a.internet_facing,
       a.indirect,
       a.auth
FROM   assets a
WHERE  a.tier = 1
  AND  a.status = 'active'
  AND  (a.owner_team IS NULL OR a.owner_confidence = 'none')
ORDER  BY a.id;

-- (d) Unknown is an answer: running images with no SBOM. Query (a) can't see these,
--     so report them next to its results instead of reading them as "not affected".
SELECT a.name,
       a.tier,
       COALESCE(a.owner_team, '(no owner)')  AS owner,
       d.cluster || '/' || d.namespace       AS running_in,
       d.image_digest
FROM   deployments d
JOIN   assets a ON a.id = d.asset_id
WHERE  NOT EXISTS (SELECT 1 FROM components c WHERE c.image_digest = d.image_digest)
ORDER  BY a.tier, a.name, running_in;
