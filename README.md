# Orion Digital Solutions — `.github`

This is the **central engineering standards repository** for the Orion Digital Solutions GitHub organization. It serves two purposes:

1. **Org-wide defaults** — community health files, issue/PR templates, and governance docs that GitHub automatically applies to every repository that does not define its own.
2. **Shared CI/CD pipelines** — reusable workflows that every project repo can adopt with a single file, giving the entire organization a consistent, maintainable CI pipeline from one source of truth.

> If you are a developer adding CI to a new repository, jump straight to [Quick Start](#quick-start--adding-ci-to-a-new-repository).

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

---

## Repository Structure

```
.github/                                ← root of this repository (this repo)
│
├── profile/
│   └── README.md                       Public-facing organization profile page
│
├── ISSUE_TEMPLATE/
│   ├── bug_report.md                   Default bug report template
│   ├── feature_request.md              Default feature request template
│   └── config.yml                      Disables blank issues; links to support
│
├── .github/
│   └── workflows/                      ← Reusable workflows (single source of truth)
│       ├── ci.yml                      Orchestrator — calls all pipelines in one run
│       ├── sonarcloud.yml              SonarCloud code quality & security scan
│       ├── secret-scanning.yml         Gitleaks secret detection
│       ├── license-compliance.yml      OSS license compliance (Trivy)
│       ├── sbom.yml                    SBOM generation (SPDX + CycloneDX)
│       └── release-please.yml          Automated versioning & GitHub Releases
│
├── workflow-templates/                 ← Starter templates (copied into project repos)
│   ├── ci.yml + .properties.json       Full Orion CI (calls the orchestrator)
│   ├── sonarcloud.yml + .json          SonarCloud only
│   ├── secret-scanning.yml + .json     Secret scanning only
│   ├── license-compliance.yml + .json  License compliance only
│   ├── sbom.yml + .json                SBOM only
│   ├── release-please.yml + .json      Release automation only
│   ├── python-ci.yml + .json           Python lint + test
│   ├── node-ci.yml + .json             Node.js build + test
│   ├── dependency-review.yml + .json   PR dependency vulnerability review
│   └── codeql-analysis.yml + .json     GitHub CodeQL static analysis
│
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
    branches: [main, develop]
  pull_request:
    branches: [main]
  release:
    types: [created]
  schedule:
    - cron: "0 6 * * 1"   # weekly full-history scan, Monday 06:00 UTC

jobs:
  ci:
    name: Orion CI
    uses: orion-digital-solutions/.github/.github/workflows/ci.yml@main
    with:
      sonar-project-key: orion-digital-solutions_YOUR-REPO-NAME   # ← change this
      release-type: python                                          # ← change or remove
    secrets: inherit
```

Replace `YOUR-REPO-NAME` with your GitHub repository name (lowercase, hyphens). See [SonarCloud Setup](#sonarcloud-setup-per-repository) for creating the project key.

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

---

## One-Time Organization Setup

These steps are performed **once by an org admin** and automatically apply to all repositories.

### Required org secrets

Navigate to **GitHub → Organization Settings → Secrets and variables → Actions** and create the secrets below.

#### SonarCloud: two tokens (scan vs report)

Orion’s pipelines use **two different SonarCloud tokens** on purpose: one drives the scanner, the other only reads data for the markdown **CI Report** in GitHub Actions. That separation keeps analysis credentials distinct from read-only API access for reporting.

| Secret | Used by | Required | Description |
|--------|---------|----------|-------------|
| `SONAR_TOKEN` | **SonarCloud scan** job (`sonarcloud.yml`) | Yes (if SonarCloud is enabled) | Token for **running the analysis** and Quality Gate (SonarScanner / `sonarcloud-github-action`). Create at [sonarcloud.io](https://sonarcloud.io) → **My Account** → **Security** → **Generate Token** (type suitable for **analysis** on your projects). |
| `SONAR_ISSUE_RETRIEVAL` | **CI Report** job (orchestrator `ci.yml` only) | Strongly recommended | Token for **read-only Web API** calls that build the Actions **Summary** (Quality Gate status, measures, top issues, hotspots). Must be able to **browse** project analysis data; it is never used to push a scan. If missing, the scan can still pass but the Summary’s detailed Sonar blocks will be degraded or empty. |

You may use two physically different tokens in SonarCloud (best for least privilege), or the same token value in both secrets **only if** that single token has both analysis and API read permissions—your org policy should prefer two tokens when possible.

#### Other org secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `GITLEAKS_LICENSE` | No | Gitleaks Pro license key. Unlocks additional secret detection rules. Leave unset to use the free ruleset. |

### Workflow permissions

Navigate to **GitHub → Organization Settings → Actions → General → Workflow permissions** and set to **"Read and write permissions"**.

This is required for `release-please` to open Release PRs and create GitHub Releases.

### SonarCloud organization

1. Sign in to [sonarcloud.io](https://sonarcloud.io) with your GitHub account.
2. Import your GitHub organization (`orion-digital-solutions`).
3. Configure **both** org Action secrets above: `SONAR_TOKEN` for scans across repos, and `SONAR_ISSUE_RETRIEVAL` so the orchestrator can render the full Sonar section in each run’s **Summary**.

---

## CI Pipeline Reference

### The Orchestrator — `ci.yml` (recommended)

The orchestrator is the **recommended way** to adopt CI. One file in your repo calls all pipelines. Updates made to the orchestrator in this `.github` repo automatically apply to every project repo on their next run — no changes needed in individual repos.

#### Execution model

The orchestrator runs checks in parallel where possible, then gates release automation on their results:

```
Phase 1 (parallel whenever configured — sonar skips if no project key; license skips on release):
  ┌─ secret-scan ──────────────────────┐
  ├─ sonarcloud  ──────────────────────┤
  └─ license-check ───────────────────┘

Phase 2 — two different dependency chains (push to main, or release for sbom only):
  ├─ release-please   (creates/updates Release PR; needs all Phase 1 jobs)
  └─ sbom             (generates SBOM artifacts; needs secret-scan + license-check only)

Release follow-up:
  └─ When a GitHub Release is created, SBOM can attach to release assets (via orchestrator `release` event and Release Please `generate-sbom-on-release`).

Always (regardless of outcome):
  └─ report           (detailed markdown summary)
```

Phase 1 jobs run in parallel where possible, so wall-clock time is driven by the slowest of secret scan, SonarCloud, and license check. **SBOM** does not wait on SonarCloud: it is gated on secret scanning and license compliance only, so it can still run if SonarCloud is skipped (for example when `sonar-project-key` is empty) or after those two succeed.

---

### Orchestrator Input Reference

```yaml
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@main
with:
  # ── SonarCloud ─────────────────────────────────────────────────────────
  sonar-project-key: ""              # Required for SonarCloud scan.
                                     # Format: orion-digital-solutions_<repo-name>
                                     # Leave blank to skip the scan.

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

  # ── Branch configuration ───────────────────────────────────────────────
  main-branch: "main"                # Default branch name. Phase 2 only runs on this branch.

  # ── License compliance ─────────────────────────────────────────────────
  forbidden-licenses: ""             # Override the org-default forbidden license list.
                                     # Format: "GPL-2.0,GPL-3.0,AGPL-3.0"
                                     # Leave blank to use the org default.

  # ── Secret scanning ────────────────────────────────────────────────────
  secret-scan-full-history: false    # Set true to force a full git history scan.
                                     # Useful when first enabling on an existing repo.

  # ── Runner ─────────────────────────────────────────────────────────────
  runner: "ubuntu-latest"            # GitHub-hosted runner label for all orchestrator jobs.
```

---

### What Runs and When

| Event | Secret Scan | SonarCloud | License | Release Please | SBOM |
|-------|:-----------:|:----------:|:-------:|:--------------:|:----:|
| `pull_request` | ✅ diff only | ✅ (if project key set) | ✅ | — | — |
| `push` to `main` | ✅ delta | ✅ (if project key set) | ✅ | ✅ (if `release-type` set) | ✅ |
| `push` to other branch | ✅ delta | ✅ (if project key set) | ✅ | — | — |
| `release` created | ✅ delta | ✅ (if project key set) | — (skipped) | — | ✅ (attach to release) |
| `schedule` (weekly) | ✅ full history | ✅ (if project key set) | ✅ | — | — |

**Delta scanning** means only changed commits are scanned for secrets on non-schedule events (including `release` triggers, which behave like a push for Gitleaks). SonarCloud still runs a full analysis of the repository on each trigger; Quality Gate and PR decoration focus on **new code** relative to your SonarCloud new-code definition. License compliance runs on the current dependency tree (Trivy) whenever that job is enabled — it is **skipped** on `release` events only. SBOM may run on `release` and attach to the release assets; Release Please may also attach SBOMs when a release is created (see [SBOM on releases (two paths)](#sbom-on-releases-two-paths) below).

---

### Using Individual Workflows

If you need only one pipeline rather than the full suite, call the reusable workflows directly.

#### Secret scanning only

```yaml
jobs:
  secrets:
    uses: orion-digital-solutions/.github/.github/workflows/secret-scanning.yml@main
    with:
      full-scan: false               # true = full history, false = delta (default)
      gitleaks-version: "v8.18.4"   # optional — pin a specific version
    secrets: inherit
```

Add a `.gitleaks.toml` file to your repository root to allowlist known false positives.

#### SonarCloud only

Uses **`SONAR_TOKEN`** only (analysis). It does **not** use `SONAR_ISSUE_RETRIEVAL`; that secret exists for the full orchestrator’s **CI Report** Summary only.

```yaml
jobs:
  sonar:
    uses: orion-digital-solutions/.github/.github/workflows/sonarcloud.yml@main
    with:
      project-key: orion-digital-solutions_my-repo   # required
      python-version: "3.11"                          # optional
      python-coverage-report: "coverage.xml"          # optional
      js-coverage-report: "coverage/lcov.info"        # optional (JS/TS)
      fail-on-quality-gate: true                      # default
    secrets: inherit
```

#### License compliance only

```yaml
jobs:
  license:
    uses: orion-digital-solutions/.github/.github/workflows/license-compliance.yml@main
    with:
      forbidden-licenses: "GPL-2.0,GPL-3.0,AGPL-3.0"   # optional override
    secrets: inherit
```

With default inputs, findings are also sent to the repository **Security → Code scanning** view via SARIF upload (the reusable workflow declares the permissions it needs).

#### SBOM generation only

```yaml
jobs:
  sbom:
    uses: orion-digital-solutions/.github/.github/workflows/sbom.yml@main
    with:
      attach-to-release: true   # attach to GitHub Release assets (default)
      attest: false             # sign with Sigstore (optional)
    secrets: inherit
```

#### Release Please only

```yaml
jobs:
  release:
    uses: orion-digital-solutions/.github/.github/workflows/release-please.yml@main
    with:
      release-type: python    # required
    secrets: inherit
```

#### Chaining release outputs to a deploy job

`release-please` exposes outputs you can use to trigger downstream jobs:

```yaml
jobs:
  release:
    uses: orion-digital-solutions/.github/.github/workflows/release-please.yml@main
    with:
      release-type: python
    secrets: inherit

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
| **Pipeline Dashboard** | Overall pass/fail banner, run metadata (trigger, commit, runner, run link), one-row status + detail per stage, quick-navigation links |
| **Secret Scanning** | Pass/fail, scan type (delta/full), Gitleaks version, findings table with severity/file/line/rule/description/commit link (secrets are redacted), remediation guidance |
| **SonarCloud** | Quality Gate status, failed gate conditions (expanded when failing), overall metrics table (bugs, vulnerabilities, hotspots, code smells, coverage, duplications, LOC, technical debt as human-readable time, A–E ratings), new code metrics, issue severity breakdown by level, top 15 open issues with severity/type/message/file/line/effort, security hotspots requiring review |
| **License Compliance** | Pass/fail, packages scanned, forbidden license list in use, violations table with package/version/license/category/severity/source file, full license inventory (collapsed) |
| **Release Please** | Whether a release was created, version/tag, link to release notes |
| **SBOM** | Generation status, output formats, link to release assets |

### SonarCloud Detail

The detailed SonarCloud blocks in the Summary are built with **`SONAR_ISSUE_RETRIEVAL`** (not `SONAR_TOKEN`). The report job issues four Web API calls:

| API | What it provides |
|-----|-----------------|
| `qualitygates/project_status` | Quality Gate pass/fail + each failed condition with actual value vs threshold |
| `measures/component` | All code metrics — bugs, vulnerabilities, smells, coverage, duplications, LOC, technical debt |
| `issues/search` | Top 15 open issues sorted by severity — with message, file, line, effort, and severity facet breakdown |
| `hotspots/search` | Security hotspots requiring review — probability, category, message, file, line |

All issue and hotspot entries link directly to SonarCloud so developers can click through to the full context.

Artifact files (`gitleaks-report`, `license-report`) are uploaded on each run for download and audit (**7-day** retention in the reusable workflows).

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
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@main
with:
  sonar-project-key: orion-digital-solutions_my-repo
  forbidden-licenses: "GPL-3.0,AGPL-3.0"   # narrower than the org default
secrets: inherit
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

### SonarCloud exclusions (per repository)

Pass `sonar.exclusions` via a `sonar-project.properties` file in your repository root. The SonarCloud workflow merges it with the workflow-level configuration.

```properties
# sonar-project.properties
sonar.exclusions=**/migrations/**,**/generated/**,**/fixtures/**
sonar.coverage.exclusions=**/tests/**,**/__init__.py
```

---

## Updating This Repository

Changes to the `workflows/` directory in this repository take effect **immediately** for every project repo on their next CI run. No changes are needed in individual repos.

### To update a pipeline org-wide

1. Create a branch: `git checkout -b fix/sonar-coverage-paths`
2. Edit the relevant file in `workflows/`.
3. Open a PR against `main` — the PR description should clearly state the impact on all consuming repositories.
4. Merge after review. All repos pick up the change automatically.

### To add a new reusable workflow

1. Add `workflows/<name>.yml` — the reusable workflow (with `on: workflow_call`).
2. Add `workflow-templates/<name>.yml` — the thin caller template for project repos.
3. Add `workflow-templates/<name>.properties.json` — metadata for the GitHub workflow template picker.
4. Document the new workflow in this README under [Using Individual Workflows](#using-individual-workflows).

### File ownership

| Area | Who maintains it |
|------|-----------------|
| `workflows/` | Engineering leads / DevOps |
| `workflow-templates/` | Engineering leads / DevOps |
| `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` | Engineering leads |
| `SECURITY.md` | Security team |
| `SUPPORT.md` | Engineering leads |
| `profile/README.md` | Marketing / Engineering leads |
| `ISSUE_TEMPLATE/` | Engineering leads |

---

*For questions about this repository, open an issue or reach out via [www.orion360.com](https://www.orion360.com/).*
