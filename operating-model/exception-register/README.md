# Exception Register

Accepted risks ("exceptions") as YAML files in Git. Every exception has an owner, a
compensating control and an expiry date. A check runs on every pull request and every
weekday, so nothing quietly stays open past its expiry.

## How it works

1. **One file per exception**, in a folder for its priority: `exceptions/p1/`,
   `exceptions/p2/`, `exceptions/p3/`, `exceptions/p4/` or `exceptions/hygiene/`.
   Start from [`exception-template.yaml`](exception-template.yaml).
2. **Adding or renewing an exception is a pull request.** CODEOWNERS makes sure the
   right approvers sign off for each priority.
3. **A check runs automatically** and fails if an exception:
   - is in the wrong priority folder;
   - is for a KEV finding (CISA's Known Exploited Vulnerabilities catalog) or a leaked live secret (P0); those can never be excepted;
   - is past its expiry date;
   - was granted for longer than its priority allows (P1: 14 days, P2: 30, P3: 90, P4 and hygiene: 180);
   - is missing a required field.

   On a pull request, a failed check blocks the merge. On the weekday run, it opens or
   updates a GitHub issue listing each problem and its owner.

## Set it up in your repo

1. Copy [`scripts/check-exceptions.sh`](scripts/check-exceptions.sh) to `scripts/check-exceptions.sh`.
2. Copy [`github/exception-expiry.yml`](github/exception-expiry.yml) to `.github/workflows/exception-expiry.yml`.
3. Copy [`github/CODEOWNERS.example`](github/CODEOWNERS.example) to `.github/CODEOWNERS` and replace the team names.
4. Create the `exceptions/` folders (see [`exceptions/`](exceptions/)).
5. In your branch ruleset, turn on **Require review from Code Owners**.

One catch: GitHub accepts any single listed owner for a CODEOWNERS line, so two approvals
could come from the same team. If you need one approval from *each* group, add a small
check for it.

The check needs bash 4+, [yq](https://github.com/mikefarah/yq) v4 and GNU date. GitHub's
`ubuntu-24.04` runners have all three.

## Tests

```bash
tests/run-tests.sh
```

Valid examples must pass, and each invalid example must fail for its own reason
(expired, too long, KEV, wrong folder, P0, missing field, bad date).

The pinned `actions/checkout` SHA in `github/exception-expiry.yml` is a template file, so
Dependabot won't update it. Re-pin it when you copy it.
