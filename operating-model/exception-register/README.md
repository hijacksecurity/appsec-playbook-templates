# Exception Register

Accepted risks ("exceptions") as YAML files in Git. Every exception has an owner, a
justification, an approver and an expiry date. P1 to P3 exceptions also need a verified
compensating control. Checks run on every pull request and every weekday, so nothing
quietly stays open past its expiry.

## Where it lives and who does what

Put this in **one central repo for the whole company** (for example `security-exceptions`), owned by AppSec. Not in each team's code repo: you get one place to see every accepted risk, and a team can't quietly approve its own exception.

| Who | What they do |
|---|---|
| The dev team that needs the exception | Opens a PR that adds one file |
| The approver for that priority | Reviews the PR and accepts the risk, or says no |
| The security reviewer for that priority | Confirms the compensating control really works, then approves (not needed for hygiene; AppSec is informed) |
| The checks (GitHub Actions) | Run on every PR and every weekday; block bad files and missing approvals, flag expired files |
| The owner (one named person) | Fixes the issue before it expires, or renews with a new PR |

When the fix ships, the team opens a PR that deletes the file. In the team's own code repo, the scanner suppression should point back to the exception ID (for example `# EXC-2026-014`), so anyone can find who approved it and when it ends.

## Who must approve

Each folder needs one approval from **each** group, from two different people. Hygiene
needs only the acceptor. The mapping lives in [`approvers.yaml`](approvers.yaml).

| Folder | Accepts the risk | Security review |
|---|---|---|
| `p1/` | `exec-approvers` | `ciso-office` |
| `p2/` | `vp-eng` | `security-leadership` |
| `p3/` | `eng-directors` | `appsec-leads` |
| `p4/` | `eng-managers` | `appsec` |
| `hygiene/` | `eng-managers` | none (AppSec is informed) |

## How it works

1. **One file per exception**, in a folder for its priority: `exceptions/p1/`,
   `exceptions/p2/`, `exceptions/p3/`, `exceptions/p4/` or `exceptions/hygiene/`.
   Start from [`exception-template.yaml`](exception-template.yaml).
2. **Adding or renewing an exception is a pull request.** CODEOWNERS asks the right
   people to review.
3. **The `approvals` check** ([`scripts/check-approvals.sh`](scripts/check-approvals.sh))
   needs one approval from each group in the table above. CODEOWNERS can't do this alone:
   GitHub accepts any one listed owner, so the Head of Security alone could merge a P2
   exception. The check reads the PR's reviews and each reviewer's team membership. It
   counts each reviewer's latest review, and only approvals of the latest commit. It runs
   again on each new review and each push.
4. **The `changed-files` check**
   ([`scripts/check-exceptions.sh`](scripts/check-exceptions.sh)) checks only the files the
   PR adds or changes. It fails if an exception:
   - is in the wrong priority folder;
   - is for a KEV finding (CISA's Known Exploited Vulnerabilities catalog) or a leaked live secret (P0); those can never be excepted;
   - is past its expiry date;
   - was granted for longer than its priority allows (P1: 14 days, P2: 30, P3: 90, P4 and hygiene: 180);
   - is missing a required field: `id`, `owner`, `priority`, `justification`,
     `accepted_by`, `approved_on`, `expires`, plus `security_review` for P1 to P4;
   - is P1, P2 or P3 and has no `compensating_control` with `type`, `description`,
     `verified_by` and `evidence`;
   - has a control of type `filter`. A filter (a WAF rule or a virtual patch) can't back an
     exception. The only allowed type is `precondition-removed`.
5. **The weekday run** checks every file. If any fail, it opens or updates a GitHub issue
   listing each problem and its owner. An expired file doesn't fail other teams' PRs; the
   weekday run reports it instead.

## Set it up in your repo

1. Copy [`scripts/`](scripts/) to `scripts/` and [`approvers.yaml`](approvers.yaml) to the
   repo root. Replace the team names in `approvers.yaml` with your team slugs.
2. Copy [`github/exception-expiry.yml`](github/exception-expiry.yml) to `.github/workflows/exception-expiry.yml`.
3. Copy [`github/CODEOWNERS.example`](github/CODEOWNERS.example) to `.github/CODEOWNERS` and replace the team names.
4. Create the `exceptions/` folders (see [`exceptions/`](exceptions/)).
5. Create a token that can read team membership, and save it as the repo secret
   `EXCEPTION_APPROVALS_TOKEN`. See below.
6. In your branch ruleset, turn on **Require review from Code Owners**, and add
   **`changed-files`** and **`approvals`** as required status checks. If `approvals` is not
   a required check, two-party approval is not enforced.

### The token for the approvals check

This is an extra setup step, and the check can't work without it. The default
`GITHUB_TOKEN` can't read org team membership. You need one of these:

- a **GitHub App** installed on the org, with the org permission "Members: read" and the
  repo permission "Pull requests: read" (best, because it isn't tied to a person); or
- a **fine-grained personal access token** with the same two permissions; or
- a classic personal access token with the `read:org` scope (plus `repo` for a private repo).

If the token is missing or can't see a team, the check fails. It never passes by mistake.
Rotate the token like any other secret. A personal token belongs to one person, so the
check breaks when that person leaves.

The checks need bash 4+, [yq](https://github.com/mikefarah/yq) v4, GNU date and the `gh`
CLI. GitHub's `ubuntu-24.04` runners have all four.

### Limits

- Deleting an exception file (the fix shipped) needs only normal review, so the approvals
  check ignores removed files.
- The approvals check runs the script and `approvers.yaml` from the base branch, so a PR
  can't change its own rules. Changes to them need Security approval through CODEOWNERS.
- A team change doesn't re-run the check. It runs on each review and each push.

## Tests

```bash
tests/run-tests.sh
```

The tests run offline. Valid examples must pass. Each invalid example must fail with the
message in its `expect` file (expired, too long, KEV, wrong folder, P0, missing field,
missing or filter control, bad date). The approvals tests feed sample reviews and team
memberships as JSON to `check-approvals.sh --decide`, with no API calls.

The pinned `actions/checkout` SHA in `github/exception-expiry.yml` is a template file, so
Dependabot won't update it. Re-pin it when you copy it.
