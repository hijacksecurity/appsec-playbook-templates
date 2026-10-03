# Threat model lite

A one-page design review. Fill it in before the design is final, in the pull request or
design doc, in about an hour. It uses the four-question framework from the
[Threat Modeling Manifesto](https://www.threatmodelingmanifesto.org/).

## When a design review is required

A review is required when a change does any of these. If none apply, no review is needed.

- [ ] Adds a new internet-facing service, endpoint or entry point (3.2's `internet_facing`)
- [ ] Changes authentication or authorization: login, sessions, tokens, roles, tenant checks
- [ ] Starts storing, processing or sending sensitive data (payment, personal data,
      credentials), or sends it somewhere new
- [ ] Adds a third-party service, SDK or integration that receives data or calls back in
- [ ] Parses files or data from users or partners (uploads, imports, webhooks)
- [ ] Changes a trust boundary: tenant isolation, admin paths, network exposure, or
      service-to-service access
- [ ] Adds or changes cryptography, key handling or secrets storage
- [ ] Adds an AI feature that can take actions (call tools, run code, send messages)
- [ ] Changes the architecture of a Tier 1 system (see `inventory/tiering-rubric.md`)

---

**System:** `name` · **Owner:** `team` · **Tier:** `1 / 2 / 3` · **Reviewer:** `security partner` · **Date:** `YYYY-MM-DD`

## 1. What are we working on?

A few sentences, plus a simple diagram (boxes and arrows is enough). Mark:

- Entry points (who can reach it: `anonymous`, `any-customer`, `staff`, `service`)
- Data stores, and the data class in each
- Trust boundaries (where data crosses from less trusted to more trusted)
- Third parties

## 2. What can go wrong?

Walk each entry point and each trust boundary. STRIDE is a useful checklist:
**S**poofing, **T**ampering, **R**epudiation, **I**nformation disclosure,
**D**enial of service, **E**levation of privilege.

| # | Threat | Where | Impact if it happens |
|---|---|---|---|
| 1 | `One merchant reads another merchant's orders` | `GET /orders/{id}` | `Cross-tenant data exposure` |
| 2 | | | |

## 3. What are we going to do about it?

| # | Response (mitigate, remove, transfer, accept) | Control | Owner | Ticket |
|---|---|---|---|---|
| 1 | Mitigate | `Tenant check in the data layer, plus a test that tries another tenant's ID` | `team` | `ABC-123` |
| 2 | | | | |

Prefer a paved-road control (shared library, platform setting) over custom code.
Accepted risks go in the exception register (3.1), with an owner and an expiry.

## 4. Did we do a good enough job?

- [ ] Every entry point and trust boundary was walked
- [ ] Every threat has a response, and every "mitigate" has a ticket or a merged change
- [ ] Tests or checks prove the key controls work
- [ ] The reviewer agrees, or the disagreement is written down
- [ ] Revisit when: `the next change that hits a trigger above`
