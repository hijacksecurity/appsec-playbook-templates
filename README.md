# AppSec Playbook Templates

Templates and working examples from **The AppSec Program Playbook**, a blog series on
building and running an application security program:
[blog.hijacksecurity.org](https://blog.hijacksecurity.org).

Everything here is meant to be copied into your own repos and adapted. Each folder
matches a part of the series.

| Folder | Series part | What's inside |
|---|---|---|
| [`operating-model/`](operating-model/) | 3.1 Operating Model | Charter template, decision record template, and a working **exception register** (accepted risks with owners and expiry dates, checked automatically) |
| [`inventory/`](inventory/) | 3.2 See Everything | Tiering rubric, `catalog-info.yaml` and asset record templates, a script that lists every GitHub Action your repos use (and which are unpinned), and **"are we affected?"** SQL queries with sample data |
| [`paved-road/`](paved-road/) | 3.3 Build the Paved Road | A GitHub Action that runs **secrets, SCA and SAST** stages, each set to block or warn; workflow hardening with zizmor and actionlint; Renovate, Dependabot, npm and pnpm settings that wait 7 days and block install scripts; a block-vs-warn policy; and a one-page threat model |

More folders will follow as the series goes on.

## How this repo stays trustworthy

- Every script has tests, and CI runs them on each change ([`.github/workflows/test.yml`](.github/workflows/test.yml)).
- GitHub Actions are pinned to full commit SHAs and kept current by Dependabot, with a 7-day cooldown.
- Examples use a fictional company, Pinecart. Nothing here comes from a real organization.

## License

[MIT](LICENSE)
