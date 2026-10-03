# Test fixtures

Small folders the CI job scans with the security-stages action. Everything here is fake.

| Folder | What's planted | Expected result with default modes |
|---|---|---|
| `clean/` | Nothing (an old, clean `ms` in the lockfile) | Passes |
| `planted-secret/` | A fake `pinecart_test_` token, a made-up format only the demo rule in `gitleaks.toml` knows | Secrets stage blocks |
| `vulnerable-dependency/` | `lodash` 4.17.20 in `package-lock.json`, which has published advisories | SCA warns; with `sca: block` it fails |
| `insecure-code/` | `subprocess.run(..., shell=True)` on request input | SAST warns; with `sast: block` it fails |
