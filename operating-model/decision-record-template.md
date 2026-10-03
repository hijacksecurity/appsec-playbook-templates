# PDR-<number>: <the decision, in one line>

<!-- A program decision record. Keep it short. The revisit date is the point:
     it makes changing your mind part of the plan, not a retreat. -->

- Status: proposed | accepted | superseded by PDR-<n>
- Date: <decision date>
- Revisit by: <date>, or earlier if <the evidence that would change your mind>
- Deciders: <names or roles>
- Door: one-way (hard to undo) | two-way (easy to undo)

## Context
What's going on, and why a decision is needed now.

## Decision
What we're doing.

## Consequences
+ What gets better.
- What gets worse, and how we'll keep that risk visible.

## Evidence we'll check at the revisit
The numbers or signals that tell us whether this worked.

---

## Example

# PDR-007: Gate on new Critical findings only, for Tier 1, starting next sprint

- Status: accepted
- Date: <decision date>
- Revisit by: <date + 90 days>, or earlier if the false-positive rate on blocked PRs exceeds 10%
- Deciders: AppSec lead, Director of Engineering (Checkout)
- Door: two-way

## Context
Gating on Critical+High blocked Checkout teams several times a week; most blocks
were in dependencies the code never calls. Teams have started asking for blanket exceptions.

## Decision
Block only on new Critical findings in Tier 1 repos. Everything else warns and goes to
the hygiene lane with a backstop deadline. KEV findings and verified live secrets always block.

## Consequences
+ Less friction; exception requests should drop.
- Risk moves out of the gate. It has to be tracked in the hygiene lane, or it disappears.

## Evidence we'll check at the revisit
Blocked-PR count, override count, hygiene-lane burn-down, exception requests per week.
