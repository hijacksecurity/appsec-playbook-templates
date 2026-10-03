# Workflow hardening

GitHub Actions workflows run with tokens and secrets, so they are part of your attack
surface. Two linters catch most of the problems before merge:

- **[zizmor](https://docs.zizmor.sh/)** finds security problems: dangerous triggers such as
  `pull_request_target`, actions not pinned to a commit SHA, broad token permissions,
  template injection, and credentials left behind by checkout.
- **[actionlint](https://github.com/rhysd/actionlint)** finds mistakes: bad syntax, wrong
  expressions, and shell bugs (it runs shellcheck on `run:` blocks).

| File | Use it for |
|---|---|
| [`workflow-lint.yml`](workflow-lint.yml) | Copy to `.github/workflows/`. Runs both linters on every change to `.github/` |
| [`install-linters.sh`](install-linters.sh) | Copy to `.github/scripts/`. Installs zizmor 1.30.1 and actionlint 1.7.12 and checks their SHA-256 |
| [`zizmor.yml`](zizmor.yml) | Copy to `.github/zizmor.yml`. Third-party actions must be SHA-pinned; your own org's actions may use a branch |
| [`tests/fixtures/insecure/`](tests/fixtures/insecure/.github/workflows/label-pr.yml) | What not to do: `pull_request_target` that checks out and runs PR code, tag-pinned actions, `permissions: write-all` |
| [`tests/fixtures/hardened/`](tests/fixtures/hardened/.github/workflows/label-pr.yml) | The same job, hardened |

## The rules the hardened version follows

1. **Don't run PR code with secrets.** `pull_request_target` gives the workflow the base
   repo's secrets and a write token, even for a PR from a fork. If it then checks out the PR
   and runs it, the PR author's code gets those secrets. Build and test on `pull_request`.
   If you need a write token (for labels or comments), use a separate
   `pull_request_target` workflow that never checks out or runs PR code.
2. **Pin every third-party action to a full commit SHA**, with the version in a comment.
   Tags can be moved to point at other code. Dependabot and Renovate keep SHA pins current.
3. **Least privilege.** `permissions: {}` at the top, then each job asks for only what it
   needs (usually `contents: read`).
4. **Don't keep the token on disk.** `persist-credentials: false` on every checkout.

## zizmor's personas

zizmor's default persona (`regular`) is what `workflow-lint.yml` runs. It reports the
pull_request_target and pinning problems above. `--persona pedantic` also reports
`write-all`, missing job names and missing concurrency limits. The hardened fixture passes
both.

## Tests

```bash
paved-road/workflow-hardening/install-linters.sh /tmp/linters     # Linux
paved-road/workflow-hardening/tests/run-tests.sh /tmp/linters
```

Needs bash and jq; zizmor runs with `--offline`. The tests check that zizmor reports
`dangerous-triggers` and `unpinned-uses` on the insecure fixture (plus
`excessive-permissions` and `artipacked` with the pedantic persona), that it reports nothing
on the hardened one, that `zizmor.yml` allows a branch-pinned action from your own org, and
that actionlint passes the hardened fixture. CI also runs both linters on this repo's own
workflows and on `workflow-lint.yml`.
