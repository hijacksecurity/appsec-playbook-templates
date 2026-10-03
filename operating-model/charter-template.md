# <Company> Application Security Charter

One page. It stops "is this ours?" arguments before they start.

**Mission.** Make the secure way the easy way for <company> engineering, so every
team gets security without extra work.

**Scope.** Software <company> builds and ships: application code, dependencies,
IaC, container images, CI/CD pipelines, the dev platform, and AI tools in the SDLC.

**AppSec owns.** Secure SDLC standards; the shared pipeline security stages and
scanner configuration; triage and prioritization; exposure analysis for advisories
("are we affected?"); the security champions program; pipeline control evidence.

**AppSec influences.** Framework and library choices; CI runner hardening; cloud
guardrails; detection content for application-layer attacks.

**Not AppSec.** Incident command and forensics (SOC/IR); cloud runtime posture
(cloud security); the control framework and audits (GRC); regulatory
interpretation and notifications (legal/privacy).

**Ownership principle.** Security owns visibility and guidance. Engineering owns
the fix. The business owns risk acceptance.

**Operating model.** Central AppSec hub + a security champion in every Tier 1 team,
with <X>% of the champion's time agreed with their manager.

**Decision rights.** Two-way-door decisions: AppSec lead. One-way-door decisions:
AppSec lead + engineering leadership, written as a decision record with a revisit date.

**Exceptions.** Per the risk-acceptance policy: the service's risk owner accepts,
security reviews, maximum expiry by priority. KEV findings and leaked live secrets
are never excepted.

**Success measures.** Ownership coverage, SLA adherence by priority, exceptions past
expiry, maturity (SAMM) change. Reported quarterly.

**Sponsor.** <exec sponsor>. **Review.** Yearly, or when the org changes shape.
