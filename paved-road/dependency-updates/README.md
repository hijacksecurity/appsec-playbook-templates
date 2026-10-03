# Dependency updates

Fast updates fix known vulnerabilities. Brand-new versions are also how malicious packages
spread: most are found and pulled from the registry within hours or days. So update quickly, but
wait **7 days** before taking a new version. Security fixes skip the wait.

| File | Tool | What it does |
|---|---|---|
| [`renovate.json`](renovate.json) | Renovate | 7-day wait; SHA pins for actions and digests for Docker images; minor, patch and digest updates grouped into one weekly PR; actions in their own PR |
| [`dependabot.yml`](dependabot.yml) | Dependabot | 7-day cooldown (14 for npm major versions), with grouped minor and patch updates |
| [`.npmrc`](.npmrc) | npm | Installs only versions at least 7 days old; never runs dependency install scripts; no git or tarball-URL dependencies |
| [`pnpm-workspace.yaml`](pnpm-workspace.yaml) | pnpm | 7-day wait; only approved packages may run install scripts; registry-only transitive dependencies; fails if a package's publishing gets weaker |

Use Renovate or Dependabot, not both, and the npm or pnpm settings for whichever you use.

## Notes on each

**Renovate.** `minimumReleaseAge: "7 days"` with `internalChecksFilter: "strict"` means
no branch or PR until a version is 7 days old. Vulnerability fixes skip the wait by
default; `vulnerabilityAlerts.minimumReleaseAge: null` says so explicitly, and they also
skip the schedule. `helpers:pinGitHubActionDigests` turns `@v4` into a full SHA with a
version comment, and `docker:pinDigests` adds `@sha256:` digests to images. Renovate also
needs the Dependency graph and Dependabot alerts turned on to see GitHub's vulnerability
alerts.

**Dependabot.** `cooldown` only applies to version updates. Dependabot security updates
are never delayed. Dependabot keeps existing SHA pins current, but it won't convert a tag
to a SHA for you: do that once (the `inventory/` script lists unpinned actions).

**npm.** `min-release-age` needs npm 11.10 or later. If a security fix is newer than 7
days, add the package to `min-release-age-exclude`. `ignore-scripts=true` works on every
npm version. It also skips your own project's `pre` and `post` scripts, so run those
explicitly. From npm 12, dependency install scripts are blocked by default unless approved
in `package.json`'s `allowScripts` (`npm install-scripts approve <pkg>`). If some packages
really need their scripts, drop `ignore-scripts`, set `strict-allow-scripts=true` so
unreviewed scripts fail the install, and approve only those packages.

**pnpm.** pnpm's `minimumReleaseAge` is in minutes (10080 is 7 days). Since pnpm 11 the
default is already 1 day; setting it makes it strict. `allowBuilds` replaces pnpm 10's
`onlyBuiltDependencies`. Approve a package with
`pnpm approve-builds`, or by hand in `allowBuilds`.

Waiting doesn't help if the package was malicious from the start, or if nobody notices
within 7 days. Keep the lockfile, review new dependencies, and keep install scripts off.

## Tests

```bash
paved-road/dependency-updates/tests/run-tests.sh
```

Needs Linux, Node.js 24 or later, python3 with venv, jq, and network access. It installs
pinned versions of the tools (Renovate 44.115.9, npm 12.1.0, pnpm 11.28.0, and
check-jsonschema from [`tests/requirements.txt`](tests/requirements.txt) with hashes),
then checks that:

- `renovate.json` passes `renovate-config-validator --strict`, and a broken copy fails;
- `dependabot.yml` matches the Dependabot schema, and a broken copy fails;
- npm loads every key in `.npmrc` (with `strict-npmrc`, an unknown key fails), and a
  dependency's postinstall script doesn't run (it does when scripts are allowed);
- pnpm fails the install when a dependency has an unapproved install script, and runs the
  script once it's approved in `allowBuilds`.

The release-age waits aren't tested directly: the result would change from day to day.
