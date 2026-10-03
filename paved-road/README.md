# Paved Road (3.3)

Templates and working examples for **3.3 Build the Paved Road** in The AppSec Program
Playbook: security that is on by default, self-serve, and updated in one place.

| Piece | What it is |
|---|---|
| [`security-stages/`](security-stages/) | A composite GitHub Action: secrets (gitleaks), SCA (osv-scanner) and SAST (semgrep). Each stage is `block`, `warn` or `off` |
| [`workflow-hardening/`](workflow-hardening/) | A workflow that runs zizmor and actionlint on your workflows, plus an insecure and a hardened example |
| [`dependency-updates/`](dependency-updates/) | Renovate and Dependabot configs with a 7-day wait, plus npm and pnpm settings that wait and block install scripts |
| [`policy/block-vs-warn.md`](policy/block-vs-warn.md) | Which findings block a merge and which only warn, using 3.4's P0 to P4 |
| [`threat-model-lite.md`](threat-model-lite.md) | A one-page design review with the four questions, and when it's required |

## Security stages

Add one step after checkout:

```yaml
permissions:
  contents: read
steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
    with:
      persist-credentials: false
  - uses: pinecart/paved-road/security-stages@main   # your org's copy of this folder
    with:
      secrets: block   # the defaults, shown for clarity
      sca: warn
      sast: warn
```

| Input | Default | Meaning |
|---|---|---|
| `path` | `.` | Folder to scan |
| `secrets` | `block` | gitleaks on the files. Uses [`gitleaks.toml`](security-stages/gitleaks.toml): gitleaks' built-in rules plus one demo rule |
| `sca` | `warn` | osv-scanner on lockfiles (`package-lock.json`, `requirements.txt`, `go.sum` and many more) |
| `sast` | `warn` | semgrep with the six rules in [`semgrep-rules/default.yml`](security-stages/semgrep-rules/default.yml) |
| `gitleaks-config`, `semgrep-config` | (the files above) | Your own config. `semgrep-config` also takes a registry ruleset such as `p/default` |

`block` fails the job on findings, and also when the tool itself fails (fail closed).
`warn` reports but never fails the job (fail open). Every run writes a table to the job
summary, and sets the outputs `secrets-result`, `sca-result` and `sast-result` (`pass`,
`findings`, `error` or `off`) plus a `-count` for each.

**How the tools are installed.** gitleaks 8.30.1 and osv-scanner 2.6.0 are downloaded
from their GitHub releases and checked against SHA-256 values written in
[`install-tools.sh`](security-stages/scripts/install-tools.sh). semgrep is installed with
pip from [`semgrep-requirements.txt`](security-stages/semgrep-requirements.txt), which pins
every package and its hash (`--require-hashes`). Linux runners only (x86_64 and arm64).

**Branch or SHA?** Pin third-party actions to a full commit SHA, always. For your own
paved-road action, referencing a branch (`@main`) lets every team get fixes and new rules
with no change on their side. The trade-off: a bad change on `main` hits everyone at once.
Protect `main` with reviews and required checks, and try changes on a test branch that a
few pilot repos use first. [`workflow-hardening/zizmor.yml`](workflow-hardening/zizmor.yml)
allows this for your own org only.

**Updating the tools.** Change the version and both checksums in `install-tools.sh` (take
them from the release's checksums file). For semgrep, change the version in
`semgrep-requirements.in` and run:

```bash
cd paved-road/security-stages
uv pip compile --universal --generate-hashes --python-version 3.12 \
  --exclude-newer "$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d)" \
  semgrep-requirements.in -o semgrep-requirements.txt
```

`--exclude-newer` applies the same 7-day wait to every dependency. If a security fix is
newer than that, add `--exclude-newer-package NAME=<today>` for that package only. The
current pin does this for semgrep 1.179.0, which moves PyJWT to a release that fixes
published advisories.

## What's real and what's made up

Pinecart is fictional. The `pinecart_test_` token format is made up, and only the demo
rule in `gitleaks.toml` knows it. It isn't a real provider's format on purpose: GitHub push
protection would block a real one, and it would look like a real leak. Delete the demo
rule, or replace it with rules for your own internal token formats.

`lodash` 4.17.20 is real and has real published advisories; that's why it's the
vulnerable fixture. If Dependabot alerts are on for your copy of this repo, expect an alert
for [`tests/fixtures/vulnerable-dependency/`](tests/fixtures/vulnerable-dependency/).

## Limits

- The stages scan the whole folder, not just the change. The new-code-only options are
  in [`policy/block-vs-warn.md`](policy/block-vs-warn.md).
- osv-scanner doesn't report KEV status, so SCA can't block on KEV alone yet. Keep SCA on
  `warn` until you add a KEV check.
- osv-scanner asks the OSV API about your package names and versions. Use its offline
  database mode if that's not allowed.
- semgrep skips files that git doesn't track, and folders in its default ignore list
  (including `tests/`). This repo's `.semgrepignore` replaces that list so the fixtures get
  scanned.

## Tests

CI runs the composite action itself on each fixture in
[`tests/fixtures/`](tests/fixtures/) and checks the result: the clean fixture passes, the
planted secret blocks, the vulnerable dependency warns (and fails with `sca: block`), and
the insecure code warns (and fails with `sast: block`). It also runs
`semgrep --test` on the rule test cases in [`tests/semgrep-rules/`](tests/semgrep-rules/).

To run the same cases locally, on Linux or in Docker:

```bash
docker run --rm -v "$PWD:/repo:ro" -w /repo ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq curl ca-certificates jq python3-venv git >/dev/null &&
  git config --global --add safe.directory /repo && paved-road/tests/run-tests.sh'
```

The other folders have their own tests; see their READMEs.
