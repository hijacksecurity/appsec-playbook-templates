# Block vs. warn

Which findings stop a merge, and which only warn. Priorities are the P0 to P4 from
**3.4 Prioritize Ruthlessly**. Copy this page into your program docs and change the rows
to match your own policy.

## The rules

1. **Only two kinds of finding block:** secrets, and dependencies on CISA's KEV list
   (Known Exploited Vulnerabilities). A verified live secret is P0. A secret pattern in new
   code blocks before anyone verifies it, because removing it before merge is cheap.
   Everything else warns, or goes to the backlog with a priority and an SLA.
2. **New code only.** A gate judges what the change adds. Findings that were already there
   never block someone else's pull request. They go to the backlog with an owner, a
   priority and an SLA.
3. **Warning is not ignoring.** Every warning is also a backlog item. Nothing is dropped.
4. **Fail closed where it blocks.** If a blocking stage can't run (the tool errors), the
   merge waits. Warning stages fail open: a tool error is reported but doesn't block.

## The table

| Finding | In new code | Already in the code | Priority (3.4) |
|---|---|---|---|
| Verified live secret | **Block.** Revoke and rotate now, then remove it | Not a merge gate. Revoke and rotate now; the owner is paged | P0 |
| Secret pattern match, not yet verified | **Block** (cheap to fix before merge). A false positive gets an allowlist entry with a reason | Backlog: verify it. If it's live, it's P0 | P0 once verified |
| Dependency on the KEV list | **Block.** Upgrade or remove it. KEV can't be excepted | Not a merge gate. P1 or P2 with a 72-hour or 7-day SLA, owner paged | P1 or P2 |
| Other dependency CVE, reachable or unknown | Warn | Backlog with priority and SLA | P2 to P4 |
| Dependency CVE, not reachable (with evidence) | Warn | Hygiene lane: grouped updates and automated patching | Hygiene (P4 if exposed with total technical impact) |
| SAST finding | Warn | Backlog, triaged with exposure and impact | P2 to P4 |
| Insecure workflow (zizmor or actionlint) | Warn | Backlog | P2 to P4 |
| Scanner error in a blocking stage | **Block** (fail closed) | Not applicable | Not applicable |
| Scanner error in a warning stage | Warn (fail open) | Not applicable | Not applicable |

"Not a merge gate" doesn't mean "wait". A P0 or P1 already in the code is an incident-level
ticket for its owner, with the 3.4 SLA running. Blocking every unrelated pull request in
the repo doesn't fix it any faster; it only teaches people to route around the gate.

## How this maps to the security-stages action

| Stage | Default mode | Why |
|---|---|---|
| `secrets` (gitleaks) | `block` | Secrets are the first blocking rule |
| `sca` (osv-scanner) | `warn` | osv-scanner reports CVEs but not KEV status. Add a KEV check (CISA's [KEV JSON feed](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)) before you set SCA to `block`, or blocking turns back into "the scanner is the judge" |
| `sast` (semgrep) | `warn` | SAST findings need triage before they mean risk |

The action scans the whole folder, not just the change. For the new-code-only rule:

- **Secrets:** scan the commits in the pull request with `gitleaks git --log-opts="BASE..HEAD"`,
  or keep a baseline report and pass `--baseline-path`.
- **SAST:** `semgrep scan --baseline-commit BASE` reports only findings the change adds.
- **SCA:** compare against the base branch's lockfile, or record accepted findings in
  `osv-scanner.toml` with a reason and an expiry.

## Exceptions

A finding that blocks and can't be fixed in time goes through the exception register from
3.1 (`operating-model/exception-register/`): an owner, approval from the risk acceptor and
from security, and an expiry date. KEV findings can't be excepted.
