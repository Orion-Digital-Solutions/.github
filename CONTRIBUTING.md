# Contributing to Orion Digital Solutions

Thank you for your interest in contributing to our projects. We welcome contributions across our areas of focus: **Data & Analytics, AI & Machine Learning, Robotic Process Automation, Software Engineering,** and **Automation**.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Branch Naming Conventions](#branch-naming-conventions)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [CI Pipeline](#ci-pipeline)
- [Development Standards](#development-standards)

---

## Code of Conduct

By participating in any of our projects, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Getting Started

1. **Fork** the repository and clone it locally.
2. **Create a branch** from `main` following the [naming conventions](#branch-naming-conventions) below.
3. **Make your changes** following our [development standards](#development-standards).
4. **Run tests** locally before pushing.
5. **Open a Pull Request** against `main` — the CI pipeline runs automatically.

---

## Branch Naming Conventions

| Type | Pattern | Example |
|---|---|---|
| Feature | `feature/<short-description>` | `feature/add-anomaly-detection` |
| Bug fix | `fix/<short-description>` | `fix/pipeline-null-reference` |
| Refactor | `refactor/<short-description>` | `refactor/etl-module-cleanup` |
| Documentation | `docs/<short-description>` | `docs/update-api-guide` |
| Hotfix | `hotfix/<short-description>` | `hotfix/auth-token-expiry` |

---

## Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This is **required**, not optional — `release-please` reads commit messages to determine version bumps and generate changelogs automatically.

### Format

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

### Types and their effect

| Type | Version bump | In changelog |
|------|:---:|:---:|
| `feat` | minor | Yes |
| `fix` | patch | Yes |
| `perf` | patch | Yes |
| `refactor` | — | Yes |
| `docs` | — | Yes |
| `test` | — | No |
| `chore` | — | No |
| `ci` | — | No |
| `feat!` or `BREAKING CHANGE:` | **major** | Yes |

### Examples

```
feat(ml-pipeline): add SHAP explainability to classification model
fix(rpa-bot): handle timeout exception in invoice processing workflow
feat!: redesign public API — removes all v1 endpoints
docs(api): update endpoint reference for v2 data export
chore(deps): bump pandas from 2.0.1 to 2.1.0
```

> **PR titles** must also follow this format. When squash-merging, the PR title becomes the commit message that `release-please` reads.

---

## Pull Request Process

1. Ensure your branch is up to date with `main`.
2. Fill out the pull request template completely.
3. Assign at least one reviewer from the relevant team.
4. All [CI checks](#ci-pipeline) must pass before merge.
5. Address all review comments before merging.
6. PRs require **at least one approving review**.
7. Squash and merge — this keeps history clean and ensures commit messages follow the Conventional Commits format.
8. Delete the source branch after merging.

---

## CI Pipeline

Every repository uses the Orion shared CI pipeline. It runs automatically on every push and pull request. Here is what it does and what you need to know.

### What runs on your PR

| Check | What it does | What causes it to fail |
|-------|-------------|------------------------|
| **Secret Scanning** | Scans new commits for leaked API keys, tokens, and credentials (Gitleaks) | Any secret pattern detected in the diff |
| **SonarCloud** | Analyses new/changed code for bugs, vulnerabilities, code smells, and coverage (new code only) | Quality Gate conditions not met on the new code |
| **License Compliance** | Scans dependencies for forbidden OSS licenses (GPL, AGPL, LGPL family) | A dependency carries a prohibited license |

### What runs on merge to `main`

All of the above, plus:

| Check | What it does |
|-------|-------------|
| **Release Please** | Reads Conventional Commit messages since the last release and opens (or updates) a Release PR with bumped version and changelog. Merging the Release PR creates the GitHub Release and Git tag. |
| **SBOM Generation** | Generates a Software Bill of Materials in SPDX and CycloneDX formats, uploads workflow artifacts, and can attach files to a GitHub Release when a release is created. SBOM is gated on secret scanning and license compliance passing — it does not wait on SonarCloud. |

SonarCloud is wired with **two org secrets**: `SONAR_TOKEN` runs the scan; `SONAR_ISSUE_RETRIEVAL` powers the detailed Sonar section in the Actions **Summary** (see [README: SonarCloud two tokens](README.md#sonarcloud-two-tokens-scan-vs-report)).

### Viewing the CI report

After a run completes, click the workflow run in the **Actions** tab, then click **Summary** in the left sidebar. The report shows:

- Secret scan status and any findings (secrets are redacted)
- SonarCloud Quality Gate status, ratings (A–E), and metrics for both overall and new code
- License violations table with package names and license identifiers (license scanning also feeds **Security → Code scanning** when SARIF upload is enabled)
- Release and SBOM status (Sonar Summary detail needs `SONAR_ISSUE_RETRIEVAL`; see org README). Download `gitleaks-report` / `license-report` workflow artifacts for full JSON (**7-day** retention).

### If CI fails on your PR

| Failing check | Action |
|--------------|--------|
| Secret scan | **Rotate the exposed credential immediately**, even if it looks like a test value. Then remove the secret from git history and add an allowlist entry to `.gitleaks.toml` if it is a genuine false positive. |
| SonarCloud | Fix the new bugs, vulnerabilities, or coverage gaps introduced by your changes. The check only reports on lines you changed — pre-existing issues will not block your PR. |
| License compliance | Remove or replace the dependency that carries the forbidden license. Open an issue if you believe the license should be permitted for this project. |

### Generating test coverage

Coverage in SonarCloud is optional. The default one-job caller in the [Quick Start](README.md#quick-start--adding-ci-to-a-new-repository) does not run your tests; the Sonar job uses its own checkout, so `coverage.xml` or `coverage/lcov.info` must exist where the scanner runs (typically after you add test steps or artifact hand-off in a **custom** workflow). Align inputs with your toolchain (`pytest --cov=. --cov-report=xml`, `jest --coverage`, etc.); details are in the central README.

### Skipping CI for documentation-only commits

GitHub Actions does **not** skip workflows based on `[skip ci]` unless each workflow defines that behaviour (for example a job-level `if:` on the commit message). The shared Orion template does **not** implement this by default. Prefer normal CI for doc-only changes unless your repository explicitly adds a skip rule (understand that skipping bypasses security and quality gates).

---

## Development Standards

### General

- Write clean, readable, and self-documenting code.
- Follow the language/framework style guide for the project (PEP 8 for Python, ESLint config for JS/TS).
- Do not commit secrets, credentials, API keys, or environment-specific configuration.
- Use `.env` files (gitignored) for local secrets; use GitHub Secrets for CI/CD.

### Data & Analytics / AI / ML

- Document data sources, transformations, and model assumptions.
- Pin dependency versions (`requirements.txt`, `pyproject.toml`, `package-lock.json`).
- Include reproducibility instructions (random seeds, environment specs).
- Store large datasets and model artifacts outside the repository (cloud storage, DVC, MLflow, etc.).

### RPA / Automation

- Test automations against sandbox or UAT environments before merging.
- Document process maps and exception-handling logic alongside the code.
- Avoid hardcoding credentials or environment-specific paths in bot configurations.

### Software Engineering

- Write unit tests for all new business logic.
- Maintain test coverage at or above the project's established threshold.
- Follow API versioning conventions for any public-facing endpoints.

---

## Questions?

Open a **Discussion** on the relevant project repository, or visit [www.orion360.com](https://www.orion360.com/).
