# Tiering Rubric

One page. Tier every asset on three axes, answer each axis on its own, then take the
**worst** one. Store the tier next to the owner in the catalog, so everyone reads the
same value.

## Sensitive data (defined once)

**Sensitive data** means these three Tier 1 data classes, and nothing else:

| `data_class` | Means |
|---|---|
| `payment` | Payment data, such as card numbers and bank details |
| `credentials` | Credentials and secrets: passwords, tokens, keys, signing material |
| `bulk-personal` | Personal data for many customers (names, addresses, order history) |

`limited-personal` (personal data in small amounts) is Tier 2. Everything else is `none`.

## The three axes

Answer each axis by itself. Don't let one axis soften another.

| Axis | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| **Business** | Revenue path or critical customer journey, **or** holds publish or deploy rights | Customer-facing, not on the critical path | Internal, not critical |
| **Data** | Sensitive data: `payment`, `credentials`, `bulk-personal` | `limited-personal` | `none` |
| **Exposure** | Exposure alone never sets Tier 1 | `internet_facing: true` **or** `indirect: true` | Internal, and not indirectly exposed |

Exposure uses the same three fields as 3.4's scorecard:

- `internet_facing`: can the internet reach it, directly or behind a gateway?
- `indirect`: does data from the internet reach it? A batch job that parses customer
  uploads counts, even with no public endpoint.
- `auth`: who can reach it: `anonymous`, `any-customer`, `staff` or `service`. It does not
  change the tier. 3.4 uses it for the "Exposed" step, and treats `any-customer` as a fake
  mitigator.

## The rules

1. **The worst axis wins.** A payment service is Tier 1 even if it isn't internet-facing.
   Never average the axes.
2. **Anything with publish credentials or production deploy rights is Tier 1**, however it
   looks to users. That includes the CI system itself.
3. **Tiers tighten, never loosen.** You can set a stricter tier than the facts give. You
   can't set a looser one.
4. **The inputs are facts, not opinions.** Record `business`, `data_class` and the exposure
   fields with the tier, so anyone can check the result.

| Tier | Rule | Pinecart examples (illustrative) |
|---|---|---|
| **Tier 1** | Revenue-critical, **or** publish or deploy rights, **or** sensitive data | Checkout, payments, auth, public storefront API, order history, the CI system |
| **Tier 2** | Customer-facing, **or** exposed (`internet_facing` or `indirect`), **or** `limited-personal` | Search, recommendations, the public docs site |
| **Tier 3** | Internal, not exposed, no personal or sensitive data, not on a critical path | Internal dashboards, internal docs, experiments |

## Tier to 3.4 impact

The tier sets the starting impact tier (`impact.tier`) in 3.4's scorecard:

| 3.2 asset tier | 3.4 starting `impact.tier` |
|---|---|
| Tier 1 | `top` |
| Tier 2 | `middle` |
| Tier 3 | `low` |

It's a starting point, not a cap:

- If a finding shows more impact than the tier assumed (credentials, deploy rights, a path
  to sensitive data), re-tier the asset. Don't cap the finding.
- A total technical impact puts a finding in `top` whatever the asset tier. Blast radius
  can lift a partial one there too.
- The tier never blocks 3.4's gate overrides: KEV or active exploitation, verified live
  secrets, and exposed or high-impact findings with unknown reachability get their
  priority whatever the tier.
