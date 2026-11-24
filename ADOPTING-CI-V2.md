# Adopting Orion CI v2

**Audience:** every team that owns a repository in `orion-digital-solutions`, and any AI coding agent (for example Claude Code) asked to make the change.
**Applies to:** new repositories, and existing repositories that call the shared CI at `@main`, `@v1` or a pinned v1 version.
**Effort:** one file edit plus one branch-protection change, about 15 minutes per repository.

---

## TL;DR

1. Your repository has **one** CI file, `.github/workflows/ci.yml`, that calls `orion-digital-solutions/.github/.github/workflows/ci.yml@v2`.
2. That file declares a `permissions:` block and passes **named secrets**, never `secrets: inherit`.
3. Your branch protection requires **exactly one** check from the shared CI: **`Orion CI / CI gate`**.

If those three are true, you are done. The rest of this page explains how to get there and what to expect.

---

## Which case are you?

| Your repository today | Go to |
|---|---|
| New repository, no CI yet | [Path A: new repository](#path-a-new-repository) |
| Has a `ci.yml` calling `...workflows/ci.yml@main`, `@v1`, `@v1.0.x` or a SHA | [Path B: existing repository](#path-b-existing-repository) |
| Calls individual shared workflows directly (`secret-scanning.yml`, `docker-lint.yml`, `sonarcloud.yml`, ...) instead of the orchestrator | [Path B](#path-b-existing-repository), then [Calling individual workflows](#calling-individual-workflows-instead-of-the-orchestrator) |
| Not sure | Run `grep -rn "orion-digital-solutions/.github/.github/workflows" .github/workflows/`. No output means Path A. |

---

## Path A: new repository

### A1. Add the CI file

Pick one:

- **GitHub UI:** repository → **Actions** → **New workflow** → section **"By Orion Digital Solutions"** → **Orion CI** → **Configure**.
- **Copy the template:** save [`workflow-templates/ci.yml`](https://github.com/Orion-Digital-Solutions/.github/blob/main/workflow-templates/ci.yml) as `.github/workflows/ci.yml` in your repository.

The template already uses `@v2`, the right triggers, the `permissions:` block and named secrets.

### A2. Edit the values marked in the template

| Setting | What to do |
|---|---|
| `sonar-project-key` | Keep the default `orion-digital-solutions_${{ github.event.repository.name }}` for a single-project repository. For a monorepo, delete it and use `sonar-projects` (see [Monorepos](#monorepos)). To skip SonarCloud, delete the line. |
| `release-type` | Release Please is **currently disabled org-wide**, so this has no effect yet. Leave it at your language (`node`, `python`, ...) or delete it. |
| `python-version` / `node-version` / `java-version` | Uncomment only what your project needs. |
| Default branch | If it is not `main`, change `on.push.branches` and add `main-branch: <name>`. |
| Coverage | SonarCloud's default gate needs coverage on new code, and **this CI does not run your tests**. See [Coverage for SonarCloud](#coverage-for-sonarcloud). |

### A3. Create the SonarCloud project (skip if you removed SonarCloud)

On [sonarcloud.io](https://sonarcloud.io), in organisation `orion-digital-solutions`, **Analyze new project** → pick the repository. The key must match `sonar-project-key`. Then **Administration → Analysis Method → turn Automatic Analysis off**. CI-based analysis fails with HTTP 403 while it is on.

### A4. Merge, then protect the default branch

Merge the CI file through a pull request first, so the check exists. Then follow [Required status check](#required-status-check).

---

## Path B: existing repository

Open `.github/workflows/ci.yml` (or whichever file calls the shared CI) and make it match the template. These are the only differences that matter:

### B1. Point at v2

```yaml
jobs:
  ci:                       # keep this job id
    name: Orion CI          # keep this name: it is part of the check name
    uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v2
```

Replace `@main`, `@v1`, `@v1.0.0`, `@v1.0.1` or a SHA with `@v2`.

### B2. Declare permissions (top level of the file)

```yaml
permissions:
  contents: write
  pull-requests: write
  security-events: write
  actions: read
  id-token: write
  attestations: write
```

GitHub checks these when the run starts, including for jobs that end up skipped. Without this block the run fails before any job starts once the org's default token becomes read-only. Each shared job narrows these further; nothing in your repository receives more than it needs.

### B3. Pass named secrets

```yaml
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_ISSUE_RETRIEVAL: ${{ secrets.SONAR_ISSUE_RETRIEVAL }}
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
      AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}
```

Delete `secrets: inherit` if you have it. It hands every org secret to the shared workflows, which only need these four.

### B4. Use the recommended triggers and concurrency (strongly recommended)

```yaml
on:
  push:
    branches: [main]
  pull_request:
  release:
    types: [created]
  schedule:
    - cron: "0 6 * * 1"

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && format('pr-{0}', github.event.pull_request.number) || github.run_id }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

With `push` on every branch **and** `pull_request`, each commit on a PR runs twice and is billed twice. In one repository that was 40% of all CI minutes.

### B5. Keep your existing inputs

No v1 input was removed. Your `sonar-*`, `docker-*`, `*-version` and `forbidden-licenses` settings work unchanged.

### B6. Update the required status check

Follow [Required status check](#required-status-check). **This step is the one that breaks merging if you skip it**: the old check names no longer exist, and GitHub waits forever for a required check that never reports.

---

## Required status check

Require only **`Orion CI / CI gate`** from the shared CI. Remove every old Orion check.

| Remove these (v1 names) | Add |
|---|---|
| `Orion CI / Resolve CI plan` | **`Orion CI / CI gate`** |
| `Orion CI / Secret Scanning / Gitleaks Secret Scan` | |
| `Orion CI / License Compliance / OSS License Compliance` | |
| `Orion CI / SonarCloud (<key>) / SonarCloud Scan` | |
| `Orion CI / Docker (<id>) / ...` (any) | |
| `Orion CI / CI Report` | |
| SonarCloud's own per-project checks (`SonarCloud Code Analysis`, ...) | |

Why only the gate: it fails whenever any part of CI fails, and it always reports, even when parts are skipped (docs-only PRs, untouched Sonar projects). A required check that is skipped never reports and blocks the PR.

**Where to change it:** repository **Settings → Rules → Rulesets** (or **Settings → Branches** for classic branch protection) → the rule for your default branch → **Require status checks to pass** → remove the old names, add `Orion CI / CI gate`. The name appears in the search box only after one run has reported it, so merge the CI change first.

To see what is required today:

```bash
gh api repos/{owner}/{repo}/rules/branches/main --jq '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
gh api repos/{owner}/{repo}/branches/main/protection/required_status_checks --jq '.contexts[]'   # classic protection
```

Your own checks (tests, builds, other workflows) are unaffected; keep requiring them.

---

## What you will see after the change

On a pull request, the run shows these jobs:

| Job | When it runs |
|---|---|
| `Orion CI / Fast checks` | Always (plan, secret scan, dependency scan, licence scan) |
| `Orion CI / SonarCloud (<key>) / SonarCloud Scan` | Only for SonarCloud projects whose files the PR changes. Pushes to `main` scan all. |
| `Orion CI / Dockerfile lint` | When the repository has Dockerfiles |
| `Orion CI / Image (<id>)` | Only with `docker-build-image: true` |
| `Orion CI / CI gate` | Always. **This is the verdict.** |

Behaviour changes compared with v1:

- **New: dependency vulnerability scan, on by default.** A known, *fixable* CRITICAL or HIGH vulnerability in your lock files fails the gate. Usually the fix is a dependency bump. Alternatives are in [Troubleshooting](#troubleshooting).
- **Documentation-only changes are cheap.** If every changed file matches `docs-only-paths` (default: `*.md`, `*.mdx`, `*.rst`, `docs/*`, `LICENSE*`, issue/PR templates, `CODEOWNERS`), SonarCloud, Dockerfile lint and image jobs are skipped; the gate still reports. About 2 billed minutes.
- **Weekly schedule** runs only the security scans (full-history secrets, dependencies, licences, image CVEs). **Release events** run only SBOM jobs.
- **Licence gate enforces the org's forbidden list** (GPL, AGPL, LGPL, EUPL and others). In some v1 setups it silently enforced nothing.
- **Secret scanning on PRs** reads `.gitleaks.toml` and `.gitleaksignore` from the base branch, so a PR cannot allowlist its own secret.
- **SonarCloud coverage:** only the report files you declare are copied into place. See [Coverage for SonarCloud](#coverage-for-sonarcloud).
- **Fewer billed minutes:** a full run went from 16 to 6 billed minutes in our test repository.

---

## Coverage for SonarCloud

CI never runs your tests. Produce coverage in your own job, upload it, and declare where it is:

```yaml
jobs:
  test:
    name: Tests + coverage
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      # ... install and run your tests with coverage here ...
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: coverage-reports
          path: |
            coverage/lcov.info
            coverage.xml

  ci:
    name: Orion CI
    needs: [test]
    uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v2
    with:
      sonar-project-key: orion-digital-solutions_${{ github.event.repository.name }}
      sonar-coverage-artifact: coverage-reports
      sonar-js-coverage-report: coverage/lcov.info      # paths as they are in the repository
      sonar-python-coverage-report: coverage.xml
      # other languages: sonar-extra-args: "-Dsonar.go.coverage.reportPaths=cov.out"
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_ISSUE_RETRIEVAL: ${{ secrets.SONAR_ISSUE_RETRIEVAL }}
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
      AZURE_NPM_TOKEN: ${{ secrets.AZURE_NPM_TOKEN }}
```

**Declare every report path.** v2 copies only declared files: the two `sonar-*-coverage-report` inputs, `*.reportPath(s)` keys in `sonar-extra-args`, or the same keys in `sonar-project.properties`. If you relied on SonarCloud's default locations without declaring them, declare them now.

## Monorepos

Use `sonar-projects` instead of `sonar-project-key`: one entry per SonarCloud project. Each `base-dir` decides which changed files trigger that project on a PR:

```yaml
      sonar-projects: >-
        [{"key":"orion-digital-solutions_myrepo-web","base-dir":"apps/web","sources":"src","js-coverage-report":"coverage/lcov.info","coverage-artifact":"coverage-reports"},
         {"key":"orion-digital-solutions_myrepo-api","base-dir":"apps/api","sources":"app","python-coverage-report":"coverage.xml","coverage-artifact":"coverage-reports","paths":["packages/shared/*"]}]
```

- Coverage paths are **relative to `base-dir`**.
- Optional `"paths"` (glob list) adds shared folders that should also trigger that project.
- Changes to `.github/workflows/` or a root `sonar-project.properties` trigger every project.
- Dockerfiles are found automatically. To list them yourself, use `docker-targets` (see the template).

## Calling individual workflows instead of the orchestrator

If you call `secret-scanning.yml`, `license-compliance.yml`, `docker-lint.yml`, `sonarcloud.yml`, `sbom.yml`, `label-sync.yml` or `stale.yml` directly, change `@main`/`@v1` to `@v2`. Copy the `permissions:` and `secrets:` blocks from the matching file in [`workflow-templates/`](https://github.com/Orion-Digital-Solutions/.github/tree/main/workflow-templates). Their inputs are unchanged.

One check-name change: in `docker-lint.yml` with `build-image: true`, **Vulnerability Scanning**, **Container Image SBOM** and **Image Efficiency (Dive)** are now steps of **Build Docker Image**. A new **Publish container SBOM** job runs only on releases or with `sbom-attest`. Update required checks if you required the old names.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Run fails instantly: *"The nested job ... is requesting '...: write', but is only allowed '...: none'"* | Missing or incomplete `permissions:` block | Add the block from [B2](#b2-declare-permissions-top-level-of-the-file) |
| PR stuck on *"Expected — Waiting for status to be reported"* | Branch protection still requires a v1 check name | [Required status check](#required-status-check) |
| `Fast checks` fails: *"Dependency scan: findings"* | A fixable CRITICAL/HIGH CVE in a lock file | Bump the dependency (the log shows the fixed version). To accept a specific CVE, add its ID on its own line to `.trivyignore` at the repository root, with a comment saying why. To narrow the scan, set `dependency-scan-severity: CRITICAL`. To opt out, set `dependency-scan: false`. |
| `.trivyignore` change has no effect on the PR | On PRs the file is read from the base branch | Merge the `.trivyignore` change first, in its own PR |
| Licence job warns that licences may be unchecked | pip, pnpm, Yarn or Go licences are not in lock files | Set `license-install-command` (see the [README](https://github.com/Orion-Digital-Solutions/.github#license-compliance-only) for per-ecosystem commands) |
| Licence job fails on a GPL/AGPL/LGPL dependency | Forbidden by org policy | Replace the dependency, or agree an exception with Engineering Leads and set `forbidden-licenses` explicitly |
| SonarCloud fails on Dependabot PRs | Dependabot PRs receive no Actions secrets | Add `SONAR_TOKEN` (and `SONAR_ISSUE_RETRIEVAL`) as **Dependabot** secrets, or pass `sonar-project-key: ${{ github.actor != 'dependabot[bot]' && 'orion-digital-solutions_<repo>' \|\| '' }}` |
| SonarCloud reports 0% coverage | Coverage not uploaded or not declared | [Coverage for SonarCloud](#coverage-for-sonarcloud); in monorepos check `base-dir` |
| SonarCloud HTTP 403 | Automatic Analysis is on in SonarCloud | Turn it off ([A3](#a3-create-the-sonarcloud-project-skip-if-you-removed-sonarcloud)) |
| Error mentioning `$/` on a self-hosted runner | Runner older than 2.336.0 | Update the runner, or use `runner: ubuntu-latest` |
| `Dockerfile lint` fails | Hadolint or Checkov finding | The job summary lists each rule per Dockerfile. Fix the Dockerfile, or document an exception with `hadolint-ignore` / `checkov-skip-check` when calling `docker-lint.yml` directly |

Still stuck: open an issue in [`orion-digital-solutions/.github`](https://github.com/Orion-Digital-Solutions/.github/issues) with a link to the failing run.

---

## Done checklist

- [ ] `.github/workflows/ci.yml` calls `orion-digital-solutions/.github/.github/workflows/ci.yml@v2`
- [ ] Calling job id is `ci` with `name: Orion CI`
- [ ] Top-level `permissions:` block as in [B2](#b2-declare-permissions-top-level-of-the-file)
- [ ] Named `secrets:` as in [B3](#b3-pass-named-secrets); no `secrets: inherit` anywhere
- [ ] Triggers and `concurrency` as in [B4](#b4-use-the-recommended-triggers-and-concurrency-strongly-recommended)
- [ ] Coverage uploaded and declared (if SonarCloud is used)
- [ ] One PR run shows `Orion CI / CI gate` green
- [ ] Branch protection requires `Orion CI / CI gate` and no v1 Orion check names

---

## For AI coding agents

You are updating one repository to Orion CI v2. Follow these steps exactly. Do not change anything this section does not mention.

**Step 1: find the caller.** Search `.github/workflows/*.yml` and `*.yaml` for `orion-digital-solutions/.github/.github/workflows/`. Matching is case-insensitive; the owner may be spelled `Orion-Digital-Solutions`.
- No match: this is a new repository. Create `.github/workflows/ci.yml` as a copy of https://raw.githubusercontent.com/Orion-Digital-Solutions/.github/main/workflow-templates/ci.yml, then go to Step 3.
- Match: edit each matching file in place (Step 2).

**Step 2: edit each calling job.**
1. Change the ref after `@` in every `uses: orion-digital-solutions/.github/.github/workflows/<file>.yml@<ref>` to `@v2`. Do not change `<file>`.
2. For the orchestrator (`ci.yml@v2`): the calling job's id must be `ci` and its `name:` must be `Orion CI`. If the id differs, ask the user before renaming it, because other jobs' `needs:` may reference it.
3. Replace `secrets: inherit` with the named block from [B3](#b3-pass-named-secrets) (orchestrator), or with the `secrets:` block of the matching template in `workflow-templates/`. Remove the `secrets:` key entirely for `license-compliance.yml`, `sbom.yml`, `release-please.yml`, `label-sync.yml` and `stale.yml`.
4. Ensure the workflow-level `permissions:` block contains at least the scopes in [B2](#b2-declare-permissions-top-level-of-the-file) (orchestrator) or in the matching template. If the file sets `permissions:` on the calling job instead, update that job-level block. Never remove scopes that other jobs in the same file need.
5. Keep every existing `with:` input and its value. Do not add inputs the repository did not have, except as the next item says.
6. If the repository uses SonarCloud with a coverage artifact but no `sonar-*-coverage-report` input and no `*.reportPath(s)` in `sonar-extra-args` or `sonar-project.properties`, add the report path(s) the test job actually produces. If you cannot tell, ask the user; do not guess.

**Step 3: triggers.** If `on.push` has no `branches` filter, or lists feature-branch patterns while `pull_request` is also present, set `on.push.branches` to the default branch only and add the `concurrency` block from [B4](#b4-use-the-recommended-triggers-and-concurrency-strongly-recommended). Keep `release`, `schedule` and `workflow_dispatch` triggers. If the default branch is not `main`, use its real name there and add `main-branch: <name>` to `with:`.

**Step 4: do not touch.** Other workflows, test jobs (other than the coverage path in Step 2.6), application code, `.trivyignore`, `.gitleaks.toml`, `.gitleaksignore`, `sonar-project.properties`.

**Step 5: validate.**
- YAML parses: `python -c "import sys,yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/*.yml`
- No inheritance left: `grep -rn "secrets: inherit" .github/workflows/` returns nothing.
- No old refs left: `grep -rniE "orion-digital-solutions/\.github/\.github/workflows/[a-z-]+\.yml@(main|v1)" .github/workflows/` returns nothing.
- If `actionlint` is available, run it on the changed files.

**Step 6: hand back to the user.** Open a pull request (or prepare the branch). In the PR description, include:
- the list of changed files;
- this reminder, verbatim: *"After this PR's first run, update branch protection: require `Orion CI / CI gate` and remove the old Orion CI check names (see ADOPTING-CI-V2.md, 'Required status check'). This PR may show as blocked until then."*
- any question from Step 2.2 or 2.6 you could not resolve.

Do not change branch protection or rulesets yourself unless the user explicitly asks you to.
