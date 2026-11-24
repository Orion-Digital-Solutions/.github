# Migrating a caller from `@main` to `@v1`

For teams whose repositories call the shared workflows in `orion-digital-solutions/.github` at `@main`. It takes about ten minutes per caller file and changes no job names, so your branch-protection required checks keep working.

**Why move now**

- `@main` changes on every merge, before a release has been tested in the sandbox. `@v1` moves only when a tested release is tagged.
- Breaking changes (`v2`: fewer jobs, new status-check names) will be developed on `main` once callers are on `@v1`. A caller still on `@main` then gets them without warning.
- The org default workflow token will be switched to read-only (ROADMAP 5.6). A caller without a `permissions:` block fails at start-up after that switch.

`@main` keeps working until you migrate. Each team migrates its own repositories.

---

## 1. Change `@main` to `@v1`

In every workflow file that calls a shared workflow, change the ref:

```yaml
# before
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@main
# after
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v1
```

Find and replace them all at once (GNU sed; on macOS use `sed -i ''`):

```bash
grep -rniE 'orion-digital-solutions/\.github/\.github/workflows/[a-z-]+\.yml@main' .github/workflows/
sed -i -E 's#(orion-digital-solutions/\.github/\.github/workflows/[a-z-]+\.yml)@main#\1@v1#I' .github/workflows/*.yml
```

The owner name is case-insensitive, so the `I` flag also catches `Orion-Digital-Solutions/...`.

## 2. Add the `permissions:` block

Copy the block for the workflow you call from the table below (it is the same block as in the matching file in [`workflow-templates/`](workflow-templates/)). Put it at the top level of the caller file, or on the job that has the `uses:` line if other jobs in the same file need different permissions.

Why it is required:

- A reusable workflow can never receive more token permissions than its caller grants. GitHub checks this **when the run starts**, against every job in the called workflow, including jobs that will be skipped (for example the disabled Release Please job still needs `pull-requests: write` granted). If anything is missing, the whole run fails before any job starts.
- Today the org default token is read and write, so callers without a block still start. Once the default becomes read-only, they will not. Each shared job narrows the grant to what it actually uses, so this block is a ceiling, not what every job gets.

| Shared workflow | `permissions:` block |
|---|---|
| `ci.yml` (orchestrator) | `contents: write`, `pull-requests: write`, `security-events: write`, `actions: read`, `id-token: write`, `attestations: write` |
| `docker-lint.yml` | `contents: write`, `security-events: write`, `actions: read`, `id-token: write`, `attestations: write` |
| `sbom.yml` | `contents: write`, `id-token: write`, `attestations: write` |
| `release-please.yml` | `contents: write`, `pull-requests: write` |
| `license-compliance.yml` | `contents: read`, `security-events: write`, `actions: read` |
| `secret-scanning.yml` | `contents: read` |
| `sonarcloud.yml` | `contents: read` |
| `label-sync.yml` | `contents: read`, `issues: write` |
| `stale.yml` | `issues: write`, `pull-requests: write` |

For the orchestrator, copy-paste:

```yaml
permissions:
  contents: write
  pull-requests: write
  security-events: write
  actions: read
  id-token: write
  attestations: write
```

## 3. Replace `secrets: inherit` with named secrets

`secrets: inherit` hands every org and repository secret to the shared workflow. Pass only what it uses. A secret that is not set is passed as empty, which is fine for the optional ones.

| Shared workflow | Secrets to pass |
|---|---|
| `ci.yml` | `SONAR_TOKEN`, `SONAR_ISSUE_RETRIEVAL`, `GITLEAKS_LICENSE`, `AZURE_NPM_TOKEN`; optional `RELEASE_APP_PRIVATE_KEY` (with `release-app-id`) |
| `docker-lint.yml` | `AZURE_NPM_TOKEN` (used only when building an image that pulls private npm packages) |
| `secret-scanning.yml` | `GITLEAKS_LICENSE` (optional) |
| `sonarcloud.yml` | `SONAR_TOKEN` |
| `release-please.yml` | none; optional `RELEASE_APP_PRIVATE_KEY` (with `app-id`) |
| `license-compliance.yml`, `sbom.yml`, `label-sync.yml`, `stale.yml` | none: delete the `secrets:` line |

For the orchestrator, copy-paste:

```yaml
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_ISSUE_RETRIEVAL: ${{ secrets.SONAR_ISSUE_RETRIEVAL }}
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
      AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}
```

If your Docker build pulls private npm packages, `AZURE_NPM_TOKEN` must be in this list: it used to arrive only through `secrets: inherit`.

## 4. New optional inputs

All are off by default; `v1` behaves the same without them, apart from the changes in step 5.

| Input | Where | What it does |
|---|---|---|
| `license-install-command` | `ci.yml` | Installs production dependencies before the licence scan. Lock files carry licence data only for npm; for pip, pnpm, Yarn and Go, Trivy reads licences from installed packages, so without this those dependencies are not checked (the job warns). Per-ecosystem commands: [README, "License compliance only"](README.md#license-compliance-only). |
| `install-command` | `license-compliance.yml` | The same, when you call the licence workflow directly. |
| `release-app-id` + secret `RELEASE_APP_PRIVATE_KEY` | `ci.yml` | GitHub App token for Release Please, so its PRs and releases trigger other workflows. Release Please is still disabled org-wide. |
| `app-id` + secret `RELEASE_APP_PRIVATE_KEY` | `release-please.yml` | The same, when you call Release Please directly. |

Example for a pnpm repository:

```yaml
    with:
      license-install-command: "corepack enable && pnpm install --frozen-lockfile --prod --ignore-scripts"
```

`release-please.yml` inputs `changelog-path`, `changelog-types` and `version-file` are deprecated and now print a warning; configure them in `release-please-config.json` with `manifest-mode: true`.

## 5. Behaviour changes you may notice

`v1.0.0` is everything merged in roadmap Phases 1 to 4. These are the changes a passing caller might see. If you are already on `@main`, you have had them since those merges.

**May newly fail a run**

- **Licence gate enforces the default list through the orchestrator.** The orchestrator used to pass an empty forbidden list, so nothing was forbidden. A blank `forbidden-licenses` now means the org default: `GPL-2.0, GPL-3.0, AGPL-1.0, AGPL-3.0, LGPL-2.0, LGPL-2.1, LGPL-3.0, EUPL-1.1, EUPL-1.2, CCDL-1.0, OSL-3.0`. Remove the dependency, or set `forbidden-licenses` with DevOps approval.
- **Gitleaks v8.18.4 to v8.30.1** (now `gitleaks git`). Newer rules can report secrets the old version missed. A `gitleaks-version` older than v8.19 still works (falls back to `detect`).
- **On pull requests, `.gitleaks.toml` and `.gitleaksignore` come from the base branch.** A PR can no longer allowlist its own secret: merge the allowlist change first, in its own PR. Inline `gitleaks:allow` comments still work.
- **Grype honours `docker-trivy-ignore-unfixed`** (and `trivy-ignore-unfixed` on `docker-lint.yml`), and its severity cutoff is the lowest level in `trivy-severity`, so both scanners gate on the same range. Only relevant with Grype enabled.
- **A failed `plan` job fails the run.** Malformed `sonar-projects` or `docker-targets` input now turns the report banner red and skips SBOM, instead of reporting "All Checks Passed".
- **`docker-exclude` globs match as written.** They were expanded by the shell before; patterns such as `samples/*` now exclude what they say.
- **Newer scanners.** Actions were upgraded (for example Trivy v0.70.0 through `trivy-action` v0.36.0, `anchore/scan-action` v7.4.2), and every action is pinned to a commit SHA. Hadolint is deliberately held at 2.12, so Dockerfile lint rules do not change in `v1`.

**Reporting and fixes (should not fail a run)**

- **Secret scan tells a crash from a finding.** A Gitleaks crash or git error is reported as a failed scan, not as "secrets found". After a force-push the scan falls back to a safe commit range instead of failing.
- **CI Report shows the right SonarCloud data.** It reads the pull request's analysis on a PR and the branch's on a non-default branch (it used to show the default branch everywhere), and no longer prints "0/N Quality Gates passed" when `SONAR_ISSUE_RETRIEVAL` is unset.
- **Label sync now syncs.** It used to do nothing; it now creates and updates labels from the org `labels.yml` (additive unless `delete-other-labels: true`).
- **Small fixes.** `hadolint-ignore` accepts commas or spaces; `docker-context` and `docker-image-name` apply to a single auto-detected Dockerfile; `sbom.yml` honours `artifact-retention-days`.

## 6. Optional: the new template triggers

The [starter templates](workflow-templates/) now run `push` only on the default branch and `pull_request` on every branch, with a `concurrency` group that cancels a PR's superseded runs. This halves the runs on a branch with an open PR (a `develop` to `main` PR used to run twice per commit). Copy the `on:` and `concurrency:` blocks from [`workflow-templates/ci.yml`](workflow-templates/ci.yml) if you want this. Keep `develop` (or similar) in `push.branches` only if it needs CI or a SonarCloud branch analysis without an open PR.

## 7. Checklist

- [ ] Every `uses: orion-digital-solutions/.github/.github/workflows/...` line ends in `@v1` (or a stricter pin, below). `grep -rni '\.github/workflows/.*@main' .github/workflows/` returns nothing.
- [ ] Each caller file (or calling job) has the `permissions:` block for the workflow it calls.
- [ ] No `secrets: inherit` remains; named secrets match the table in step 3.
- [ ] `AZURE_NPM_TOKEN` is passed if the Docker build pulls private npm packages.
- [ ] For pip, pnpm, Yarn or Go: `license-install-command` (or `install-command`) is set, or the licence warning is accepted.
- [ ] Opened a PR with the change: the run starts (no start-up permission error), every expected job runs, and the CI Report looks right.
- [ ] Required status checks in branch protection still match (job names did not change in `v1`).

## Staying strict: pin a release or a SHA

`@v1` moves to each new `v1.x.y` release after it passes the sandbox, so you get fixes without editing your files. If you want to choose when you upgrade:

```yaml
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v1.0.0
# or, immune to any tag change:
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@<full 40-character commit SHA>   # v1.0.0
```

`vX.Y.Z` tags are never moved or deleted. With either pin you must update the ref yourself to receive fixes; see the [release notes](https://github.com/Orion-Digital-Solutions/.github/releases) and [How callers pin](CONTRIBUTING.md#how-callers-pin).

Questions or a failing migration: open an issue in this repository.

---

# Migrating from v1 to v2

> v2 is released (`v2.0.0`, moving tag `v2`). `@v1` stays available for repos that have not migrated yet but receives no new features.

v2 runs the same checks in far fewer jobs. In the sandbox, a full run went from 16 billed minutes to 6, and a docs-only pull request costs 2.

## What you change

1. **`@v1` → `@v2`** on the orchestrator call. Keep the calling job's `name: Orion CI`; it is part of the check name.
2. **Required status checks.** Remove every old Orion CI check from your branch protection or ruleset and require **only `Orion CI / CI gate`**. The old names (`Orion CI / Resolve CI plan`, `… / Secret Scanning / Gitleaks Secret Scan`, `… / License Compliance / OSS License Compliance`, `… / SonarCloud (<key>) / SonarCloud Scan`, `… / Docker (<id>) / …`, `… / CI Report`) no longer exist, and required checks that never report block merging. Also stop requiring SonarCloud's own per-project checks: projects a PR does not touch are no longer scanned and post nothing.
3. **Nothing else is required.** The `permissions:` block and named secrets are the same as v1; no inputs were removed.

## What changes in behaviour

- **One "Fast checks" job** runs plan, secret scan and licence scan; **one "Dockerfile lint" job** lints every Dockerfile; the opt-in image job builds, scans, generates SBOMs and runs Dive in one job per image.
- **Pull requests scan only the SonarCloud projects they touch** (by `base-dir`, or the new optional `"paths"` globs per project). Pushes to `main` always scan every project.
- **Docs-only changes** (new input `docs-only-paths`, sensible default; blank disables it) skip Sonar, Dockerfile lint and image jobs on PRs and non-main pushes. Secret and licence scans still run.
- **Schedule** runs only the full-history secret scan, the licence scan and (if enabled) the image CVE scan. **Release** runs only SBOM generation and publishing.
- **Self-hosted runners** passed through `runner:` must be runner 2.336.0 or newer (v2 uses the `$/` self-repository action syntax).
- **New: dependency vulnerability scan (on by default).** Fast checks runs Trivy against your lock files and manifests; a **fixable CRITICAL or HIGH CVE now fails `CI gate`**. Options: fix it (usually a dependency bump), accept a specific CVE in `.trivyignore` at the repo root (on PRs this file is read from the base branch, so a PR cannot ignore its own new CVE), narrow it with `dependency-scan-severity: CRITICAL`, or opt out with `dependency-scan: false`. Commit lock files: without them only exact version pins are checked.
- **Gitleaks findings appear in the Security tab** on public repositories (full-history and PR scans).
- **SonarCloud coverage:** the coverage artifact is no longer extracted over your checkout. Only the report files you declare (`sonar-python-coverage-report`, `sonar-js-coverage-report`, `*.reportPath(s)` in `sonar-extra-args` or `sonar-project.properties`) are copied into place. If you relied on SonarCloud's default report locations without declaring them, declare them.
