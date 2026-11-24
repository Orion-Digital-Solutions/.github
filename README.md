# Orion Digital Solutions — `.github`

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Orion-Digital-Solutions/.github/badge)](https://scorecard.dev/viewer/?uri=github.com/Orion-Digital-Solutions/.github)

This is the **central engineering standards repository** for the Orion Digital Solutions GitHub organization. It serves two purposes:

1. **Org-wide defaults** — community health files, issue/PR templates, and governance docs that GitHub automatically applies to every repository that does not define its own.
2. **Shared CI/CD pipelines** — reusable workflows that every project repo can adopt with a single file, giving the entire organization a consistent, maintainable CI pipeline from one source of truth.

> If you are a developer adding CI to a new repository, jump straight to [Quick Start](#quick-start--adding-ci-to-a-new-repository).
>
> Already calling the shared workflows at `@main`? Follow [MIGRATION.md](MIGRATION.md) to move to `@v1`.

---

## Table of Contents

- [Repository Structure](#repository-structure)
- [Quick Start — Adding CI to a New Repository](#quick-start--adding-ci-to-a-new-repository)
- [One-Time Organization Setup](#one-time-organization-setup)
- [CI Pipeline Reference](#ci-pipeline-reference)
  - [The Orchestrator — `ci.yml`](#the-orchestrator--ciyml-recommended)
  - [Input Reference](#orchestrator-input-reference)
  - [What Runs and When](#what-runs-and-when)
  - [Using Individual Workflows](#using-individual-workflows)
- [The CI Report](#the-ci-report)
- [SonarCloud Setup](#sonarcloud-setup-per-repository)
- [Commit Message Convention](#commit-message-convention)
- [Overriding Org Defaults](#overriding-org-defaults)
- [Updating This Repository](#updating-this-repository)
- [Migrating from `@main` to `@v1`](MIGRATION.md)

---

## Repository Structure

```
.github/                                ← root of this repository (this repo)
│
├── profile/
│   └── README.md                       Public-facing organization profile page
│
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml                  Default bug report form (GitHub issue form)
│   ├── feature_request.yml             Default feature request form
│   └── config.yml                      Disables blank issues; links to support
│
├── labels.yml                          Central label definitions (used by label-sync workflow)
│
├── .github/
│   └── workflows/                      ← Reusable workflows (single source of truth)
│       ├── ci.yml                      Orchestrator — calls all pipelines in one run
│       ├── sonarcloud.yml              SonarCloud code quality & security scan
│       ├── secret-scanning.yml         Gitleaks secret detection
│       ├── license-compliance.yml      OSS license compliance (Trivy)
│       ├── docker-lint.yml             Dockerfile lint, image CVE scan, container SBOM, Dive
│       ├── sbom.yml                    SBOM generation (SPDX + CycloneDX)
│       ├── release-please.yml          Automated versioning & GitHub Releases
│       ├── label-sync.yml              Sync `labels.yml` to repository labels
│       └── stale.yml                   Stale issue/PR automation (optional caller)
│
├── workflow-templates/                 ← Starter templates (copied into project repos)
│   ├── ci.yml + .properties.json       Full Orion CI (calls the orchestrator)
│   ├── docker-lint.yml + .json         Docker best-practices pipeline only
│   ├── sonarcloud.yml + .json          SonarCloud only
│   ├── secret-scanning.yml + .json     Secret scanning only
│   ├── license-compliance.yml + .json  License compliance only
│   ├── sbom.yml + .json                SBOM only
│   ├── release-please.yml + .json      Release automation only
│   ├── label-sync.yml + .json          Label sync from org defaults
│   ├── stale.yml + .json               Stale issue/PR workflow
│   ├── python-ci.yml + .json           Python lint + test
│   ├── node-ci.yml + .json             Node.js build + test
│   ├── dependency-review.yml + .json   PR dependency vulnerability review
│   └── codeql-analysis.yml + .json     GitHub CodeQL static analysis
│
├── MIGRATION.md                        Moving a caller from @main to @v1
├── ROADMAP.md                          CI/CD roadmap for the shared workflows
├── CODE_OF_CONDUCT.md                  Community standards (org-wide default)
├── CONTRIBUTING.md                     Contribution guidelines (org-wide default)
├── SECURITY.md                         Vulnerability disclosure policy (org-wide default)
├── SUPPORT.md                          Support channels (org-wide default)
└── PULL_REQUEST_TEMPLATE.md            Default PR checklist (org-wide default)
```

---

## Quick Start — Adding CI to a New Repository

This is the **only file** you need to add to a project repository to get the full Orion CI pipeline running.

### Step 1 — Create the workflow file

Create `.github/workflows/ci.yml` at the root of your project repository (standard GitHub Actions layout — a single `.github` folder):

```yaml
name: Orion CI

on:
  push:
    branches: [main]      # default branch only; PRs cover every other branch
  pull_request:
  release:
    types: [created]
  schedule:
    - cron: "0 6 * * 1"   # weekly full-history scan, Monday 06:00 UTC

# New commits on a PR cancel that PR's older run; other runs are never cancelled.
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && format('pr-{0}', github.event.pull_request.number) || github.run_id }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# Maximum the orchestrator requests; each shared job narrows further.
# Required — see "Workflow permissions" below.
permissions:
  contents: write
  pull-requests: write
  security-events: write
  actions: read
  id-token: write
  attestations: write

jobs:
  ci:
    name: Orion CI
    uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v1
    with:
      sonar-project-key: orion-digital-solutions_YOUR-REPO-NAME   # ← change this
      release-type: python                                          # ← change or remove
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_ISSUE_RETRIEVAL: ${{ secrets.SONAR_ISSUE_RETRIEVAL }}
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
      AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}
```

Replace `YOUR-REPO-NAME` with your GitHub repository name (lowercase, hyphens). See [SonarCloud Setup](#sonarcloud-setup-per-repository) for creating the project key.

Keep the `permissions:` block and pass secrets by name as shown — do **not** use `secrets: inherit`, which hands every org secret to the shared workflows. A secret that is not set at org or repo level is simply passed as empty.

Reference the shared workflows at **`@v1`**, the moving tag for the latest `v1.x.y` release. To choose when you upgrade, pin `@v1.0.0` (or any `vX.Y.Z`) or a full commit SHA instead. Do not use `@main`: it changes on every merge, before a release has been tested. See [How callers pin](CONTRIBUTING.md#how-callers-pin).

### Step 2 — Set your release type

Set `release-type` to match your project. If you do not want automated releases, remove the line entirely.

| Project type | `release-type` value |
|---|---|
| Python | `python` |
| Node.js / TypeScript | `node` |
| Java (Maven) | `maven` |
| Java (Gradle) | `gradle` |
| .NET | `dotnet` |
| Go | `go` |
| Rust, Helm, other types | See [googleapis/release-please](https://github.com/googleapis/release-please) (release types documentation) |
| No manifest / generic | `simple` |

### Step 3 — Create the SonarCloud project

See [SonarCloud Setup](#sonarcloud-setup-per-repository) below.

### Step 4 — Push

Commit and push the workflow file. The pipeline will run on the next push or PR. Check the **Actions** tab → select the run → **Summary** tab at the top of the run for the consolidated CI report.

The triggers and `concurrency` block above (the same as in the [starter template](workflow-templates/ci.yml)) keep billed minutes down:

- **One run per commit on a PR.** `push` fires only on the default branch and `pull_request` covers every other branch, so a push to a branch with an open PR starts one run, not a push run plus a PR run. If you need CI on a long-lived branch such as `develop` without an open PR, add it to `push.branches` and accept the second run while a PR from it is open. If your default branch is not `main`, change the trigger and set the `main-branch` input.
- **Superseded PR runs are cancelled.** A new commit on a PR cancels that PR's run still in progress. Pushes to the default branch, releases and scheduled runs each get their own group, so they are never cancelled or dropped from a queue.

---

## One-Time Organization Setup

These steps are performed **once by an org admin** and automatically apply to all repositories.

### Required org secrets

Navigate to **GitHub → Organization Settings → Secrets and variables → Actions** and create the secrets below.

#### SonarCloud: two tokens (scan vs report)

Orion’s pipelines use **two different SonarCloud tokens** on purpose: one drives the scanner, the other only reads data for the markdown **CI Report** in GitHub Actions. That separation keeps analysis credentials distinct from read-only API access for reporting.

| Secret | Used by | Required | Description |
|--------|---------|----------|-------------|
| `SONAR_TOKEN` | **SonarCloud scan** job (`sonarcloud.yml`) | Yes (if SonarCloud is enabled) | Token for **running the analysis** and Quality Gate (SonarScanner / `SonarSource/sonarqube-scan-action`). Create at [sonarcloud.io](https://sonarcloud.io) → **My Account** → **Security** → **Generate Token** (type suitable for **analysis** on your projects). |
| `SONAR_ISSUE_RETRIEVAL` | **CI Report** job (orchestrator `ci.yml` only) | Strongly recommended | Token for **read-only Web API** calls that build the Actions **Summary** (Quality Gate status, measures, top issues, hotspots). Must be able to **browse** project analysis data; it is never used to push a scan. If missing, the scan can still pass but the Summary’s detailed Sonar blocks will be degraded or empty. |

You may use two physically different tokens in SonarCloud (best for least privilege), or the same token value in both secrets **only if** that single token has both analysis and API read permissions—your org policy should prefer two tokens when possible.

#### Other org secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `GITLEAKS_LICENSE` | No | Gitleaks Pro license key. Unlocks additional secret detection rules. Leave unset to use the free ruleset. |
| `AZURE_NPM_TOKEN` | No | Read-only token for the private Azure Artifacts npm feed. Passed to the Docker image build as a BuildKit secret, only when the build pulls private npm packages. |
| `RELEASE_APP_PRIVATE_KEY` | No | Private key (PEM) of a GitHub App used to mint the Release Please token, together with the `release-app-id` input (`app-id` when calling `release-please.yml` directly). Release PRs and releases created with the default `GITHUB_TOKEN` do not trigger other workflows; with the App they do. If either the key or the App ID is missing, Release Please falls back to `GITHUB_TOKEN`. The App needs Contents, Pull requests and Issues set to Read and write. |

### Workflow permissions

Navigate to **GitHub → Organization Settings → Actions → General → Workflow permissions** and set to **"Read repository contents and packages permissions"** (read-only).

Do **not** grant "Read and write" org-wide. Instead, every workflow declares the token permissions it needs in its own `permissions:` block, as the [starter templates](workflow-templates/) do. A reusable workflow can never receive more than its caller grants, so each template lists the maximum its shared workflow requests (for example `contents: write` and `pull-requests: write` for Release Please), and each shared job narrows that further.

> **Callers without a `permissions:` block will fail once the default is read-only.** The shared workflows request write scopes (`contents`, `pull-requests`, `security-events`, `id-token`, `attestations`), and GitHub rejects the run at start-up if the caller does not grant them — even for jobs that would be skipped. Copy the `permissions:` block from the matching template before the org default is switched.

### SonarCloud organization

1. Sign in to [sonarcloud.io](https://sonarcloud.io) with your GitHub account.
2. Import your GitHub organization (`orion-digital-solutions`).
3. Configure **both** org Action secrets above: `SONAR_TOKEN` for scans across repos, and `SONAR_ISSUE_RETRIEVAL` so the orchestrator can render the full Sonar section in each run’s **Summary**.

---

## CI Pipeline Reference

### The Orchestrator — `ci.yml` (recommended)

The orchestrator is the **recommended way** to adopt CI. One file in your repo calls all pipelines. Fixes and compatible features reach every repo that calls `@v1` when the `v1` tag is moved to a new release — no changes needed in individual repos. Breaking changes go to a new major tag (`v2`) that you adopt deliberately. The orchestrator calls its child workflows by **relative path** (`./.github/workflows/<file>.yml`), so they always come from the same commit as the `ci.yml` your repo references.

#### Execution model

The orchestrator runs checks in parallel where possible, then gates release automation on their results:

```
Phase 1 (parallel — sonar/docker skip if nothing resolved; license skips on release):
  ┌─ plan ─────────────────────────────►  (always; normalises scalar OR list inputs into
  │                                         sonar-projects[] + docker-targets[] + counts)
  ├─ secret-scan ──────────────────────┤
  ├─ sonarcloud  (matrix over plan's sonar-projects — one leg per project; skip if count 0)
  ├─ license-check ────────────────────┤
  └─ docker-lint (matrix over plan's docker-targets — one leg per Dockerfile; skip if count 0;
                  Hadolint, Checkov, then Trivy/Grype/Syft/Dive when docker-build-image: true)

Phase 2 — push to main (or release for SBOM attach):
  ├─ release-please   (needs plan, secret-scan, sonarcloud, license-check, docker-lint — all
  │                    must pass or be skipped; skipped jobs do not block)
  │                    *** currently disabled org-wide in the orchestrator ***
  └─ sbom             (same needs and rule as release-please; a skipped SonarCloud or
                       Docker job does not block it, a failed one does)

  A failed plan (malformed caller inputs) fails the run: the matrix jobs, release-please
  and sbom are skipped, and the report banner turns red.

Release follow-up:
  └─ When a GitHub Release is created, SBOM can attach to release assets (orchestrator `release`
     event and Release Please `generate-sbom-on-release`).

Always (regardless of outcome):
  └─ report           (Actions Summary — Sonar APIs, Gitleaks + license + docker-vuln artifacts)
```

Phase 1 wall-clock time is driven by the slowest of the scans plus Docker (when enabled). **SBOM** waits for all Phase 1 jobs, but only a **failed** (or cancelled) job blocks it: it still runs when SonarCloud or Docker is skipped (for example when `sonar-project-key` is empty or no Dockerfile is found).

---

### Orchestrator Input Reference

```yaml
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v1
with:
  # ── SonarCloud (single project) ────────────────────────────────────────
  sonar-project-key: ""              # Single-project scan.
                                     # Format: orion-digital-solutions_<repo-name>
                                     # Leave blank to skip, or when using sonar-projects.
  sonar-sources: "."                 # Directory to analyse for the single-project path.

  # ── SonarCloud (monorepo) ──────────────────────────────────────────────
  # Mutually exclusive with sonar-project-key. JSON array, one object per
  # sub-project — each its own SonarCloud project, Quality Gate, and PR check.
  # A PR touching several sub-projects posts a separate gate check per project.
  # Per-element keys: key (required), base-dir, sources, project-name,
  # node-version, python-version, java-version, js-coverage-report,
  # python-coverage-report, coverage-artifact, sonar-extra-args.
  # Set base-dir to the sub-project's directory (e.g. apps/web); sources,
  # exclusions, and coverage paths are then RELATIVE to it, so the coverage
  # tools' app-relative report paths resolve (otherwise SonarCloud looks at the
  # repo root and reports 0% coverage).
  sonar-projects: ""                 # e.g. '[{"key":"...","base-dir":"apps/web","sources":"src", ...}, ...]'

  sonar-python-coverage-report: ""   # Path to pytest XML coverage report.
                                     # e.g. "coverage.xml"
                                     # Generate with: pytest --cov=. --cov-report=xml

  sonar-js-coverage-report: ""       # Path to Jest LCOV coverage report.
                                     # e.g. "coverage/lcov.info"
                                     # Generate with: jest --coverage

  # ── Runtime setup ──────────────────────────────────────────────────────
  # Only set what your project needs — unset values are skipped.
  python-version: ""                 # e.g. "3.11"
  node-version: ""                   # e.g. "20"
  java-version: ""                   # e.g. "17"

  # ── Release automation ─────────────────────────────────────────────────
  release-type: ""                   # Passed to Release Please — common values:
                                     # python | node | java | maven | gradle | dotnet | go | simple
                                     # See Release Please docs for the full list.
                                     # Leave blank to disable automated releases.
                                     # Note: the release-please job is currently
                                     # disabled org-wide in the orchestrator.
  release-app-id: ""                 # GitHub App ID for the Release Please token, so its
                                     # PRs and releases trigger other workflows. Also pass
                                     # secret RELEASE_APP_PRIVATE_KEY. Blank = GITHUB_TOKEN.

  # ── Branch configuration ───────────────────────────────────────────────
  main-branch: "main"                # Default branch name. Phase 2 only runs on this branch.

  # ── License compliance ─────────────────────────────────────────────────
  forbidden-licenses: ""             # Override the org-default forbidden license list.
                                     # Format: "GPL-2.0,GPL-3.0,AGPL-3.0"
                                     # Leave blank to use the org default.
  license-install-command: ""        # Installs production dependencies before the
                                     # licence scan, so Trivy can read licences that lock
                                     # files don't carry (pip, pnpm, Yarn, Go).
                                     # Blank = scan lock files only (with a warning).
                                     # See "License compliance only" below.

  # ── Secret scanning ────────────────────────────────────────────────────
  secret-scan-full-history: false    # Set true to force a full git history scan.
                                     # Useful when first enabling on an existing repo.

  # ── Runner ─────────────────────────────────────────────────────────────
  runner: "ubuntu-latest"            # GitHub-hosted runner label for all orchestrator jobs.

  # ── Docker (optional; auto-detects ALL Dockerfiles) ────────────────────
  # By default every Dockerfile in the repo is linted (one matrix leg each),
  # excluding non-production paths (examples, test, tests, fixtures, docs,
  # node_modules, vendor). Use the controls below to pin or prune targets.
  dockerfile: ""                     # Pin ONE explicit Dockerfile path (disables auto-detect)
  docker-targets: ""                 # Monorepo: explicit JSON array of {dockerfile, context?, image-name?}
                                     # (mutually exclusive with dockerfile; disables auto-detect)
  docker-exclude: ""                 # Extra path globs to skip during auto-detect (comma/space-separated)
  docker-context: ""                 # Build context for `dockerfile`, or for the one
                                     # Dockerfile auto-detect finds (ignored with a
                                     # warning if it finds several — use docker-targets)
  docker-image-name: ""              # CI image tag, same scope as docker-context
                                     # (default: per-target orion-docker-check-<id>:ci)
  docker-trivy-severity: "CRITICAL,HIGH"  # also sets the Grype cutoff (its lowest level)
  docker-trivy-ignore-unfixed: false  # true = ignore CVEs with no upstream fix yet
  docker-dive-enable: true
  docker-dive-min-efficiency: 0.9    # Dive layer efficiency threshold (0.0–1.0)
  docker-grype-enable: false         # optional second CVE scanner alongside Trivy
```

---

### Monorepo support (multiple Sonar projects / Dockerfiles)

The orchestrator handles a single-project repo and a monorepo with the **same**
`ci.yml` — a single project is just a length-1 list. Pass the list inputs instead
of the scalars:

- **SonarCloud:** `sonar-projects` — a JSON array, one object per sub-project. Each
  becomes its own SonarCloud project (own key, Quality Gate, and PR decoration), so a
  PR touching several sub-projects posts a **separate, project-labelled gate check for
  each**, scoped to that project's `sources`. Create each project in SonarCloud first
  via **Add new project** under the monorepo binding, using unique keys
  (`orion-digital-solutions_<repo>-<component>`). Set each element's **`base-dir`** to
  the sub-project's directory (e.g. `apps/web`); `sources` and the coverage report
  paths are then **relative to it**, so the app-relative paths your test tools emit
  resolve — without `base-dir`, SonarCloud looks at the repo root and reports **0%
  coverage**.
- **Docker:** by default **all** Dockerfiles are auto-detected and linted (one matrix
  leg each), minus the built-in non-production excludes and any `docker-exclude` globs.
  Pass `docker-targets` to pin an explicit set instead.

```yaml
with:
  sonar-projects: >-
    [{"key":"orion-digital-solutions_myrepo-web","base-dir":"apps/web","sources":"src","node-version":"20","js-coverage-report":"coverage/lcov.info","coverage-artifact":"web-cov"},
     {"key":"orion-digital-solutions_myrepo-api","base-dir":"apps/api","sources":"src","node-version":"20","js-coverage-report":"coverage/lcov.info","coverage-artifact":"api-cov"},
     {"key":"orion-digital-solutions_myrepo-py","base-dir":"services/py","sources":"src","python-version":"3.12","python-coverage-report":"coverage.xml","coverage-artifact":"py-cov"}]
  docker-targets: >-
    [{"dockerfile":"apps/web/Dockerfile","context":"apps/web"},
     {"dockerfile":"apps/api/Dockerfile","context":"apps/api"}]
secrets:
  SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  SONAR_ISSUE_RETRIEVAL: ${{ secrets.SONAR_ISSUE_RETRIEVAL }}
  GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
  AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}
```

(Fragment of the `ci` job — keep the workflow-level `permissions:` block from [Step 1](#step-1--create-the-workflow-file).)

**Rules:** the scalar (`sonar-project-key` / `dockerfile`) and its list counterpart
(`sonar-projects` / `docker-targets`) are mutually exclusive — passing both fails the
`plan` job with a clear error. Coverage and per-language runtime are set **per element**
in `sonar-projects` (not via the top-level `sonar-*-coverage-report` / `*-version`
inputs, which serve the single-project path).

**Enforcement:** SonarCloud does not offer its own merge-block for monorepo projects.
Enforce gates via **GitHub branch protection → required status checks**, marking each
project's check (e.g. `SonarCloud (…-web)`, `SonarCloud (…-api)`) as required.

---

### What Runs and When

| Event | Secret Scan | SonarCloud | License | Docker pipeline | Release Please | SBOM |
|-------|:-----------:|:----------:|:-------:|:-----------------:|:--------------:|:----:|
| `pull_request` | ✅ diff only | ✅ (if project key set) | ✅ | ✅ if Dockerfile found | — | — |
| `push` to `main` | ✅ delta | ✅ (if project key set) | ✅ | ✅ if Dockerfile found | ✅ (if `release-type` set; currently disabled) | ✅ |
| `push` to other branch | ✅ delta | ✅ (if project key set) | ✅ | ✅ if Dockerfile found | — | — |
| `release` created | ✅ delta | ✅ (if project key set) | — (skipped) | ✅ if Dockerfile found | — | ✅ (attach to release) |
| `schedule` (weekly) | ✅ full history | ✅ (if project key set) | ✅ | ✅ if Dockerfile found | — | — |

This table is what the orchestrator does for each event it receives. The [Quick Start](#step-1--create-the-workflow-file) triggers send it `push` only for the default branch; add other branches to `push.branches` to get the "other branch" row.

**Docker pipeline** lints **every** `Dockerfile` in the repo — at the root or any subdirectory (e.g. `apps/api/Dockerfile`, also matches `Dockerfile.*` variants), one matrix leg per file. Non-production paths (`examples`, `test`, `tests`, `fixtures`, `docs`, `node_modules`, `vendor`) are excluded, plus any `docker-exclude` globs; each leg's build context defaults to its Dockerfile's directory. Pin a single file with `dockerfile`, or an explicit set with `docker-targets` (either disables auto-detect). If no Dockerfile is found, the Docker job is **skipped** and does not block Release Please.

**Delta scanning** means only changed commits are scanned for secrets on non-schedule events (including `release` triggers, which behave like a push for Gitleaks). SonarCloud still runs a full analysis of the repository on each trigger; Quality Gate and PR decoration focus on **new code** relative to your SonarCloud new-code definition. License compliance runs on the current dependency tree (Trivy) whenever that job is enabled — it is **skipped** on `release` events only. SBOM may run on `release` and attach to the release assets; Release Please may also attach SBOMs when a release is created (see [SBOM on releases (two paths)](#sbom-on-releases-two-paths) below).

---

### Using Individual Workflows

If you need only one pipeline rather than the full suite, call the reusable workflows directly. Each example shows the workflow-level `permissions:` block and the named secrets that workflow needs (see [Workflow permissions](#workflow-permissions)); the matching file in [`workflow-templates/`](workflow-templates/) has the same blocks.

#### Secret scanning only

```yaml
permissions:
  contents: read

jobs:
  secrets:
    uses: orion-digital-solutions/.github/.github/workflows/secret-scanning.yml@v1
    with:
      full-scan: false               # true = full history, false = delta (default)
      gitleaks-version: "v8.30.1"   # optional — pin a specific version
    secrets:
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

Add a `.gitleaks.toml` file to your repository root to allowlist known false positives (on pull requests it is read from the base branch — see [Gitleaks allowlist](#gitleaks-allowlist-per-repository)). The Gitleaks download is verified against the release's SHA-256 checksums file before it is installed, and a Gitleaks crash is reported as a failed scan, separately from a secret finding.

#### Docker best practices only

When you are **not** using the full orchestrator, you can call the shared Docker pipeline directly (you must pass a `dockerfile` path):

```yaml
permissions:
  contents: write
  security-events: write
  actions: read
  id-token: write
  attestations: write

jobs:
  docker:
    uses: orion-digital-solutions/.github/.github/workflows/docker-lint.yml@v1
    with:
      dockerfile: Dockerfile
      image-name: myapp:ci
    secrets:
      AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}   # only used when building the image
```

The orchestrator already includes Dockerfile detection and this workflow; use the standalone call only for repos that want Docker checks without the rest of Orion CI.

`hadolint-ignore` (standalone call only) accepts rule IDs separated by commas or spaces (e.g. `DL3008,SC2035` or `DL3008 SC2035`). When `grype-enable` is true, Grype fails at the **lowest** severity listed in `trivy-severity` (the default `CRITICAL,HIGH` gives `high`), so both scanners gate on the same range.

#### SonarCloud only

Uses **`SONAR_TOKEN`** only (analysis). It does **not** use `SONAR_ISSUE_RETRIEVAL`; that secret exists for the full orchestrator’s **CI Report** Summary only.

```yaml
permissions:
  contents: read

jobs:
  sonar:
    uses: orion-digital-solutions/.github/.github/workflows/sonarcloud.yml@v1
    with:
      project-key: orion-digital-solutions_my-repo   # required
      python-version: "3.11"                          # optional
      python-coverage-report: "coverage.xml"          # optional
      js-coverage-report: "coverage/lcov.info"        # optional (JS/TS)
      fail-on-quality-gate: true                      # default
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

#### License compliance only

No secrets are needed.

```yaml
permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  license:
    uses: orion-digital-solutions/.github/.github/workflows/license-compliance.yml@v1
    with:
      forbidden-licenses: "GPL-2.0,GPL-3.0,AGPL-3.0"   # optional override; blank = default list
      install-command: "npm ci --omit=dev --ignore-scripts"   # optional, see below
```

With default inputs, findings are also sent to the repository **Security → Code scanning** view via SARIF upload (this is why the caller grants `security-events: write`).

**Install command.** Lock files carry licence data only for npm (`package-lock.json`). For pip, pnpm, Yarn and Go, Trivy reads licences from installed packages, so set `install-command` (orchestrator: `license-install-command`) to install production dependencies where Trivy looks. Without it the job emits a warning and the licence gate may pass without checking those dependencies. The command runs from the repository root; prefix `cd <dir> &&` for a project in a subdirectory.

| Ecosystem | Where Trivy looks | Example `install-command` |
|---|---|---|
| pip (`requirements.txt`) | site-packages of the venv in `$VIRTUAL_ENV` (the runner's system Python has none), so create a venv and export `VIRTUAL_ENV` via `$GITHUB_ENV` | `python3 -m venv "$RUNNER_TEMP/venv" && "$RUNNER_TEMP/venv/bin/pip" install -r requirements.txt && echo "VIRTUAL_ENV=$RUNNER_TEMP/venv" >> "$GITHUB_ENV"` |
| pnpm | `node_modules` next to `pnpm-lock.yaml`, inside `scan-path` | `corepack enable && pnpm install --frozen-lockfile --prod --ignore-scripts` |
| Yarn Classic | `node_modules` next to `yarn.lock`, inside `scan-path` | `yarn install --frozen-lockfile --production --ignore-scripts` |
| Yarn 2+ | `.yarn/cache` (or `.yarn/unplugged`) next to `yarn.lock`; turn off Yarn 4's global cache | `corepack enable && YARN_ENABLE_GLOBAL_CACHE=false yarn install --immutable` |
| Go | `vendor/` next to `go.mod`, or `$GOPATH/pkg/mod` (a custom `GOMODCACHE` is not read) | `go mod download` |

Pipenv, Poetry and uv lock files get no licence data from Trivy at all.

#### SBOM generation only

No secrets are needed.

```yaml
permissions:
  contents: write
  id-token: write
  attestations: write

jobs:
  sbom:
    uses: orion-digital-solutions/.github/.github/workflows/sbom.yml@v1
    with:
      attach-to-release: true   # attach to GitHub Release assets (default)
      attest: false             # sign with Sigstore (optional)
```

#### Release Please only

No secrets are needed by default. Optionally pass a GitHub App so Release PRs and releases trigger other workflows (see `RELEASE_APP_PRIVATE_KEY` under [Other org secrets](#other-org-secrets)).

```yaml
permissions:
  contents: write
  pull-requests: write

jobs:
  release:
    uses: orion-digital-solutions/.github/.github/workflows/release-please.yml@v1
    with:
      release-type: python    # required (or manifest-mode: true)
      app-id: ${{ vars.RELEASE_APP_ID }}   # optional — GitHub App token
    secrets:
      RELEASE_APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}   # optional, with app-id
```

The `changelog-path`, `changelog-types` and `version-file` inputs are **deprecated**: release-please-action (v4 and later) ignores them (the workflow warns if you set one). Configure the changelog path, changelog sections and extra files in `release-please-config.json` instead, using `manifest-mode: true` (a single package is just the `"."` entry).

#### Chaining release outputs to a deploy job

`release-please` exposes outputs you can use to trigger downstream jobs:

```yaml
permissions:
  contents: write
  pull-requests: write

jobs:
  release:
    uses: orion-digital-solutions/.github/.github/workflows/release-please.yml@v1
    with:
      release-type: python

  deploy:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying version ${{ needs.release.outputs.version }}"
```

---

## The CI Report

After every run, a consolidated report is written to the GitHub Actions **Summary** tab. To view it:

1. Go to the **Actions** tab of your repository.
2. Click the workflow run.
3. Click **Summary** at the top of the left sidebar.

The report always renders, even when upstream jobs fail. The CI Report job itself never fails — failures in individual checks are surfaced through the upstream job statuses and the report content.

### Report Structure

The report opens with a **Pipeline Dashboard** — a single at-a-glance table showing status and a one-line detail for every stage, followed by quick-navigation links to each section.

| Section | What it shows |
|---------|---------------|
| **Pipeline Dashboard** | Overall pass/fail banner, run metadata (trigger, commit, runner, run link), one-row status + detail per stage (including the plan job and Docker; a failed plan flags invalid caller inputs and points to its job log), quick-navigation links |
| **Secret Scanning** | Pass/fail, scan type (delta/full), Gitleaks version, findings table with severity/file/line/rule/description/commit link (secrets are redacted), remediation guidance |
| **SonarCloud** | Quality Gate status, failed gate conditions (expanded when failing), overall metrics table (bugs, vulnerabilities, hotspots, code smells, coverage, duplications, LOC, technical debt as human-readable time, A–E ratings), new code metrics, issue severity breakdown by level, top 15 open issues with severity/type/message/file/line/effort, security hotspots requiring review |
| **License Compliance** | Pass/fail, packages scanned, forbidden license list in use, violations table with package/version/license/category/severity/source file, full license inventory (collapsed) |
| **Docker Best Practices** | Skipped when no Dockerfile; otherwise Hadolint/Checkov/Trivy (and optional Grype), Dive efficiency, container SBOM — with sub-check summary and CVE highlights from `docker-vuln-report` |
| **Release Please** | Whether a release was created, version/tag, link to release notes |
| **SBOM** | Generation status, output formats, link to release assets |

### SonarCloud Detail

The detailed SonarCloud blocks in the Summary are built with **`SONAR_ISSUE_RETRIEVAL`** (not `SONAR_TOKEN`). The report renders **one collapsible block per project** (with an `N/M Quality Gates passed` rollup), issuing these four Web API calls for each. The calls are scoped to the analysis that was just scanned: the pull request (`pullRequest=<n>`) on a `pull_request` run, the branch (`branch=<name>`) on a push to a non-main branch, and the main branch otherwise.

| API | What it provides |
|-----|-----------------|
| `qualitygates/project_status` | Quality Gate pass/fail + each failed condition with actual value vs threshold |
| `measures/component` | All code metrics — bugs, vulnerabilities, smells, coverage, duplications, LOC, technical debt |
| `issues/search` | Top 15 open issues sorted by severity — with message, file, line, effort, and severity facet breakdown |
| `hotspots/search` | Security hotspots requiring review — probability, category, message, file, line |

All issue and hotspot entries link directly to SonarCloud so developers can click through to the full context.

Artifact files (`gitleaks-report`, `license-report`, and when Docker builds/scans, one `docker-vuln-report*` per image plus related Docker artifacts) are uploaded for download and audit (**7-day** retention where set in the reusable workflows; Docker image tar artifacts may use shorter retention — see `docker-lint.yml`).

### SBOM on releases (two paths)

1. **Orchestrator `sbom` job** — Runs when your caller workflow triggers on `release` (and on push to `main`). Attaches SPDX + CycloneDX when `attach-to-release` is true.
2. **Release Please `post-release` job** — When `generate-sbom-on-release` is true (the orchestrator sets this), the reusable `release-please.yml` workflow also runs `sbom-action` and uploads release assets immediately after a release is created.

Using the **full Quick Start** with both **Release** triggers and default inputs can therefore produce SBOMs from both paths around the same release. That is redundant by design for traceability; to rely on a single path, set `generate-sbom-on-release: false` via a custom orchestrator fork or call `release-please.yml` directly with that input disabled.

---

## SonarCloud Setup (per repository)

Each repository that uses SonarCloud needs a project created once.

### Option A — Auto-provisioning (recommended)

1. Push the `ci.yml` workflow file to your repo with a valid `sonar-project-key`.
2. On the first run, SonarCloud will auto-create the project if the `SONAR_TOKEN` has admin scope.
3. Verify the project appears at `https://sonarcloud.io/project/overview?id=YOUR-PROJECT-KEY`.

### Option B — Manual creation

1. Go to [sonarcloud.io](https://sonarcloud.io) → **+** → **Analyze new project**.
2. Select the repository from the `orion-digital-solutions` organization.
3. Note the **Project Key** shown during setup (format: `orion-digital-solutions_<repo-name>`).
4. Use that key as `sonar-project-key` in your workflow.

### New Code baseline (main branch)

For accurate delta reporting on the `main` branch, set the new code definition once per project:

1. SonarCloud → your project → **Administration** → **New Code**.
2. Set to **"Previous version"**.

This makes the Quality Gate focus on regressions introduced since the last release rather than pre-existing issues.

### Passing coverage to SonarCloud

Coverage in SonarCloud is optional but valuable. The shared **SonarCloud** reusable workflow checks out your repository on its own runner and points the scanner at the paths you pass in (`sonar-python-coverage-report`, `sonar-js-coverage-report`). Those files must **exist on that checkout** when the scanner runs.

The standard [one-job Quick Start](#quick-start--adding-ci-to-a-new-repository) only invokes the orchestrator and does **not** run your test suite, so coverage files are usually absent unless you generate them some other way.

**Practical options:**

1. **Add a dedicated workflow or job** in your repository that checks out the code, installs dependencies, runs tests with coverage, and ensures `coverage.xml` or `coverage/lcov.info` is present in the workspace—then either call Sonar with those paths (today this may require **customizing** how you chain jobs and artifacts, or invoking `sonarcloud.yml` from a job that already ran tests) or work with DevOps to extend the shared workflows to download a coverage artifact before scan.
2. **Start without coverage inputs** and enable them once your repo’s workflow reliably produces reports in the same filesystem as the scanner step.

Repository-specific examples belong in your service repo; keep `sonar-python-coverage-report` / `sonar-js-coverage-report` in sync with where your tests write reports (for example `pytest --cov=. --cov-report=xml` → `coverage.xml`, `jest --coverage` → `coverage/lcov.info`).

---

## Commit Message Convention

Orion follows the [Conventional Commits](https://www.conventionalcommits.org/) specification. This is **required** — `release-please` reads commit messages to determine version bumps and generate the changelog.

### Format

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

### Types and version impact

| Type | Version bump | Appears in changelog |
|------|:------------:|:--------------------:|
| `feat` | minor (1.0.0 → 1.1.0) | Yes |
| `fix` | patch (1.0.0 → 1.0.1) | Yes |
| `perf` | patch | Yes |
| `refactor` | none | Yes |
| `docs` | none | Yes |
| `test` | none | No |
| `chore` | none | No |
| `ci` | none | No |
| `feat!` or `BREAKING CHANGE:` footer | major (1.0.0 → 2.0.0) | Yes |

### Examples

```
feat(ml-pipeline): add SHAP explainability to classification model
fix(rpa-bot): handle timeout exception in invoice processing workflow
feat!: redesign public API — removes v1 endpoints
docs(api): update endpoint reference for v2 data export
chore(deps): bump pandas from 2.0.1 to 2.1.0
```

### PR title

PR titles must also follow Conventional Commits format. The PR title becomes the squash-merge commit message, which is what `release-please` reads. A PR title linter can be added via the `workflow-templates/` directory.

---

## Overriding Org Defaults

### Community health files

GitHub automatically uses the files in this repository (`CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `PULL_REQUEST_TEMPLATE.md`) for any repository that does not define its own. To override for a specific repository, create the same file at the same path inside that repository.

### Workflow behaviour per repository

Every input to the orchestrator and individual workflows has a documented default. Override at the call site:

```yaml
# Override the forbidden license list for a repo with specific requirements
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v1
with:
  sonar-project-key: orion-digital-solutions_my-repo
  forbidden-licenses: "GPL-3.0,AGPL-3.0"   # narrower than the org default
secrets:
  SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  SONAR_ISSUE_RETRIEVAL: ${{ secrets.SONAR_ISSUE_RETRIEVAL }}
  GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
  AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}
```

### Gitleaks allowlist (per repository)

To allowlist a known false positive secret pattern, add a `.gitleaks.toml` to your repository root. The secret scanner picks it up automatically.

```toml
# .gitleaks.toml
[allowlist]
  description = "Known false positives"
  regexes = ['''example-key-do-not-use''']
  paths = ['''tests/fixtures/''']
```

On **pull requests**, `.gitleaks.toml` and `.gitleaksignore` are read from the **base branch**, not the PR head, so a PR cannot allowlist its own secret: a new or changed allowlist takes effect only once it is merged. Inline `gitleaks:allow` comments in the PR's own lines are still honoured, so reviewers should watch for them. Other events use the checked-out files.

### SonarCloud exclusions (per repository)

Pass `sonar.exclusions` via a `sonar-project.properties` file in your repository root. The SonarCloud workflow merges it with the workflow-level configuration.

```properties
# sonar-project.properties
sonar.exclusions=**/migrations/**,**/generated/**,**/fixtures/**
sonar.coverage.exclusions=**/tests/**,**/__init__.py
```

---

### Dependabot pull requests and secrets

Workflows triggered by Dependabot pull requests **do not receive Actions secrets** (they get only the Dependabot secrets store) and run with a read-only `GITHUB_TOKEN`. With the shared CI this means:

- **SonarCloud fails** on Dependabot PRs: `SONAR_TOKEN` is empty, so the scanner cannot authenticate.
- **The CI Report** shows no SonarCloud detail (`SONAR_ISSUE_RETRIEVAL` is empty).
- **Docker builds** that need `AZURE_NPM_TOKEN` fail to install private packages.

Pick one per repository:

1. **Recommended:** add the needed tokens as **Dependabot secrets** (Organization or repository Settings → Secrets and variables → **Dependabot**), using separate, read-only tokens where the provider allows it. They are passed to the same secret names.
2. Skip the scan for Dependabot in your caller, e.g. pass `sonar-project-key: ${{ github.actor != 'dependabot[bot]' && 'orion-digital-solutions_my-repo' || '' }}`. An empty key skips SonarCloud.

Secret scanning, licence compliance and Dockerfile lint need no secrets and run normally on Dependabot PRs.

## Updating This Repository

Callers reference a release tag (`@v1`), so a merge to `main` does not reach them by itself: a change reaches every `@v1` caller on its next run once the `v1` tag is moved to a release that contains it. Callers still on `@main` (see [MIGRATION.md](MIGRATION.md)) pick up every merge immediately.

### To update a pipeline org-wide

1. Create a branch: `git checkout -b fix/sonar-coverage-paths`
2. Edit the relevant file under `.github/workflows/`.
3. Open a PR against `main` — the PR description should clearly state the impact on all consuming repositories, and link sandbox runs.
4. Merge after review, then tag a release and move `v1` as described in [CONTRIBUTING.md — Releasing the shared workflows](CONTRIBUTING.md#releasing-the-shared-workflows). A breaking change gets a new major tag instead.

Every third-party action, in the shared workflows and in the templates, is pinned to a full commit SHA with the version in a trailing comment (`uses: actions/checkout@<sha> # v7.0.1`), so a moved or hijacked tag cannot change what runs. Dependabot ([`.github/dependabot.yml`](.github/dependabot.yml)) bumps the pins in `.github/workflows/` weekly, with a 7-day cool-down so a new release is at least a week old before it is proposed. Dependabot does not scan `workflow-templates/`: when you merge a Dependabot bump, update the same pins in the templates by hand.

### To add a new reusable workflow

1. Add `.github/workflows/<name>.yml` — the reusable workflow (with `on: workflow_call`).
2. Add `workflow-templates/<name>.yml` — the thin caller template for project repos.
3. Add `workflow-templates/<name>.properties.json` — metadata for the GitHub workflow template picker.
4. Document the new workflow in this README under [Using Individual Workflows](#using-individual-workflows).

### File ownership

| Area | Who maintains it |
|------|-----------------|
| `.github/workflows/` | Engineering leads / DevOps |
| `workflow-templates/` | Engineering leads / DevOps |
| `labels.yml` (with label-sync) | Engineering leads / DevOps |
| `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` | Engineering leads |
| `SECURITY.md` | Security team |
| `SUPPORT.md` | Engineering leads |
| `profile/README.md` | Marketing / Engineering leads |
| `ISSUE_TEMPLATE/` | Engineering leads |

---

*For questions about this repository, open an issue or reach out via [www.orion360.com](https://www.orion360.com/).*
