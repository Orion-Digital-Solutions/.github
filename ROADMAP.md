# CI/CD Roadmap — shared workflows in `orion-digital-solutions/.github`

Drafted 23 November 2026 from a review of every workflow in this repository, checked against the upstream action definitions, GitHub's hardening guidance, and measured run data from two caller repositories.

**Scope:** this repository only (the reusable workflows in `.github/workflows/` and the starter templates in `workflow-templates/`). Caller repositories are not changed by this roadmap, but several items change what callers must do, and those are called out.

**How to read it:** phases are in priority order with no dates. Each item has a size estimate (S = up to half a day, M = one to two days, L = three days or more), the items it depends on, a blank owner column, and a "done when" check. Items marked *settings* are GitHub configuration for an org owner; everything else is a pull request to this repository.

---

## Why this is needed

1. **One push to `main` reaches every caller.** This repository is public, `main` has no branch protection or rulesets, and 18 repositories run its workflows at `@main` with `secrets: inherit`. `CODEOWNERS` exists but nothing enforces it.
2. **Several workflows do not do what the documentation says.** Label sync reads no label file, the orchestrator drops the default forbidden-licence list, the CI Report shows the default branch's Sonar data on pull requests, and SBOMs are never attached to Release Please releases.
3. **About a third of billed minutes are rounding.** GitHub bills every job rounded up to a whole minute. In a measured caller run the orchestrator's 11 jobs used 475 seconds of compute and were billed 14 minutes.
4. **Most pinned actions are behind.** `anchore/scan-action` is four major versions old, Gitleaks is twelve minor versions old, and `actions/attest-sbom` is deprecated.

## Decisions already made

| Topic | Decision |
|---|---|
| How callers reference the workflows | A protected `v1` tag. Breaking changes go to `v2`. |
| Job structure | Full consolidation of the small jobs, accepting that status-check names change. |
| Org repo scanner (`Imported_repo_scanning.yml`) | Remove it and delete its three public runs. |
| Release Please | Fix it, but keep it disabled. |
| Org default workflow token | Flip to read-only, after explicit permissions are in place. |
| Third-party actions | Pin every action to a commit SHA; Dependabot keeps them current. The org-wide "require SHA" policy stays off because it would also forbid `@v1`. |
| Licence gate | Add an optional install step; warn when it is not used. |
| SonarCloud in monorepos | Scan only changed projects on pull requests; always scan all projects on the main branch. |
| Weekly schedule | Runs the full-history secret scan, the licence check, and the image CVE scan. Sonar and Docker lint are skipped. |
| GitHub plan | Team. See "What the Team plan limits" below. |

## Status

Updated 23 November 2026.

| Phase | State |
|---|---|
| 0 | Settings for an org owner. Commands (PowerShell) were handed over; apply 0.1-0.6 if not done. With the `protect-main` ruleset, every PR needs a second approver. |
| 1 | Done: [#14](https://github.com/Orion-Digital-Solutions/.github/pull/14). |
| 2 | Done: [#16](https://github.com/Orion-Digital-Solutions/.github/pull/16) ([#15](https://github.com/Orion-Digital-Solutions/.github/pull/15) was closed and replaced by #16). Item 5.1 (relative child references) was done early, in this phase. |
| 3 | Done: [#18](https://github.com/Orion-Digital-Solutions/.github/pull/18). Hadolint is held at v3.1.0 (Hadolint 2.12) for `v1`; see 3.6. |
| 4 | Done: [#20](https://github.com/Orion-Digital-Solutions/.github/pull/20). The sandbox caller (4.3) is [`Orion-Digital-Solutions/ci-sandbox`](https://github.com/Orion-Digital-Solutions/ci-sandbox). |
| 5 | Released: [v1.0.0](https://github.com/Orion-Digital-Solutions/.github/releases/tag/v1.0.0) (Phases 1-4) and [v1.0.1](https://github.com/Orion-Digital-Solutions/.github/releases/tag/v1.0.1) ([#21](https://github.com/Orion-Digital-Solutions/.github/pull/21): `@v1` docs, [MIGRATION.md](MIGRATION.md), template items 6.7 and 6.10). Open: 5.2 tag ruleset (org owner), caller migration (owners of the 18 repos), then 5.6 org token default to read-only. |
| 6 | Built and validated in the sandbox on draft [#22](https://github.com/Orion-Digital-Solutions/.github/pull/22) (`ci/v2-dev`): full run 16 → 6 billed minutes, docs-only PR 2. **Not merged until callers are on `@v1`** (check names change). Before release: test SonarCloud change detection from one real monorepo caller, then tag `v2.0.0`/`v2`. 6.11 (`ubuntu-slim` light runner) not done: optional. |
| 7 | 7.1-7.3 on draft #22 (dependency CVE scan, Gitleaks SARIF, isolated Sonar coverage), validated including a failing-gate test. 7.4-7.5 done: [#23](https://github.com/Orion-Digital-Solutions/.github/pull/23) (OpenSSF Scorecard, Dependabot-secrets note). 7.6 (attestations on private repos) not available on the Team plan. |

## Release plan in one view

| Release | Contains | Breaking for callers? |
|---|---|---|
| `v1.0.0` (tag `v1`) | Phases 1 to 4: security fixes, bug fixes, version upgrades, guard rails. Same jobs and inputs as today. | No. Callers change `@main` to `@v1` and add a `permissions:` block. |
| `v2.0.0` (tag `v2`) | Phase 6: consolidated jobs, change detection, event gating. | Yes. Status-check names change. |

---

## Phase 0 — Contain the exposure (settings only)

No code changes. Do these first; none depends on anything else.

| ID | Item | Size | Owner | Done when |
|---|---|---|---|---|
| 0.1 | Add a ruleset on `main` of this repository: require a pull request, one approval, code-owner review, and block force-push and deletion, with no bypass list. | S | | `gh api repos/Orion-Digital-Solutions/.github/rules/branches/main` returns rules instead of `[]`. |
| 0.2 | Delete the three public runs of "Gitleaks Org Repo Scanner" from 4 May 2026. Their titles and logs can name private repositories. | S | | The workflow's run list is empty. |
| 0.3 | Revoke the `ORG_ACCESS_TOKEN` personal access token and delete the org secret. It is only used by the scanner being removed in 1.1. | S | | Secret no longer listed; token revoked at its owner's account. |
| 0.4 | Turn on secret scanning and push protection for this repository. Both are free on public repositories and currently disabled. | S | | Repository security settings show both enabled. |
| 0.5 | Review who has write access to this repository and reduce it to the workflow maintainers. `CODEOWNERS` currently implies four teams, including marketing for `profile/`. | S | | Access list reviewed and recorded. |
| 0.6 | Review which repositories can see each org secret (`SONAR_TOKEN`, `SONAR_ISSUE_RETRIEVAL`, `AZURE_NPM_TOKEN`, `GITLEAKS_LICENSE`). Confirm `AZURE_NPM_TOKEN` is read-only and scoped to the registry. | S | | Visibility per secret recorded; token scope confirmed. |

## Phase 1 — Security fixes in code

| ID | Item | Where | Size | Depends on | Owner | Done when |
|---|---|---|---|---|---|---|
| 1.1 | Delete the org repo scanner workflow and remove any mention of it from the README. | `.github/workflows/Imported_repo_scanning.yml`, [README.md](README.md) | S | 0.2, 0.3 | | File gone; no doc mentions it. |
| 1.2 | Stop pasting expressions into shell scripts. Pass every `${{ ... }}` value through `env:`. The tag-name cases are exploitable by anyone who can create a release. | [sbom.yml:128-132](.github/workflows/sbom.yml#L128-L132), [docker-lint.yml:446](.github/workflows/docker-lint.yml#L446), [:670](.github/workflows/docker-lint.yml#L670), [:759](.github/workflows/docker-lint.yml#L759), [sonarcloud.yml:242-283](.github/workflows/sonarcloud.yml#L242-L283), [secret-scanning.yml:139-150](.github/workflows/secret-scanning.yml#L139-L150) | M | | | `zizmor` (item 4.1) reports no template-injection findings. |
| 1.3 | Give every job explicit, minimal permissions. The `plan` and `report` jobs and all of `sonarcloud.yml` have none. `docker-lint.yml` and `sbom.yml` grant `contents: write` and `id-token: write` to every job; move those to the single job that needs them. | [ci.yml:352](.github/workflows/ci.yml#L352), [:592](.github/workflows/ci.yml#L592), [sonarcloud.yml:148](.github/workflows/sonarcloud.yml#L148), [docker-lint.yml:217-222](.github/workflows/docker-lint.yml#L217-L222), [sbom.yml:74-77](.github/workflows/sbom.yml#L74-L77) | M | | | Every job has a `permissions:` block; the build job that runs a PR's Dockerfile has read-only access. |
| 1.4 | Add a `permissions:` block to every starter template that calls a reusable workflow. A called workflow cannot be granted more than its caller, so the template must list what the called jobs need. | `workflow-templates/*.yml` | S | 1.3 | | A template run succeeds in a repository whose default token is read-only. |
| 1.5 | Replace `secrets: inherit` with named secrets. Licence, SBOM, stale and label sync need none. Declare `AZURE_NPM_TOKEN` in the `workflow_call.secrets` of `docker-lint.yml`, where it is used but never declared. | [ci.yml:342](.github/workflows/ci.yml#L342), [:539](.github/workflows/ci.yml#L539), [:569](.github/workflows/ci.yml#L569), [:586](.github/workflows/ci.yml#L586), [docker-lint.yml:428](.github/workflows/docker-lint.yml#L428), templates | M | | | No `secrets: inherit` remains in this repository. |
| 1.6 | Pin every action to a full commit SHA with the version in a trailing comment. Replace the floating `anchore/sbom-action@v0` and `checkov-action@v12`. Pin the Dive image by digest instead of `:latest`. | All workflows; [docker-lint.yml:818](.github/workflows/docker-lint.yml#L818) | M | Phase 3 (pin the upgraded versions, not the old ones) | | No `uses:` line references a tag or branch. |
| 1.7 | Verify the Gitleaks download against the release checksum file before installing it. | [secret-scanning.yml:73-76](.github/workflows/secret-scanning.yml#L73-L76) | S | | | Install step fails on a checksum mismatch. |
| 1.8 | Add `.github/dependabot.yml` for the `github-actions` ecosystem, weekly, with grouped updates. | New file | S | 1.6 | | Dependabot opens an update PR. |
| 1.9 | On pull requests, read `.gitleaks.toml` from the base branch, so a PR cannot allowlist its own secret. | [secret-scanning.yml:116](.github/workflows/secret-scanning.yml#L116) | S | | | A PR that adds an allowlist entry and a matching secret still fails. |
| 1.10 | Correct the README, which tells admins to set the org default to "Read and write". | [README.md:168](README.md#L168) | S | 1.4 | | README states read-only and points to the template `permissions:` blocks. |
| 1.11 | Remove `.claude/settings.local.json` from the repository and add it to `.gitignore`. It holds only local paths. | [.claude/settings.local.json](.claude/settings.local.json) | S | | | File untracked and ignored. |

## Phase 2 — Bugs: behaviour that differs from the documentation

| ID | Item | Where | Size | Owner | Done when |
|---|---|---|---|---|---|
| 2.1 | Label sync passes `source:`, which is not an input of `EndBug/label-sync@v2`. Change it to `config-file: labels.yml`. | [label-sync.yml:74](.github/workflows/label-sync.yml#L74) | S | | A run creates or updates labels from `labels.yml`. |
| 2.2 | The orchestrator always passes an empty `forbidden-licenses`, which overrides the default list. Apply the default when the input is empty. | [ci.yml:340](.github/workflows/ci.yml#L340), [license-compliance.yml:27](.github/workflows/license-compliance.yml#L27) | S | | A test repository with an AGPL dependency fails the gate when called through the orchestrator. |
| 2.3 | Add an optional `install-command` input to the licence workflow. When set, production dependencies are installed before the scan. When unset, the job warns that pip, pnpm, Yarn and Go licences cannot be read from lock files alone. | [license-compliance.yml](.github/workflows/license-compliance.yml) | M | | Warning appears without the input; a Python test repository reports licences with it. |
| 2.4 | The CI Report queries SonarCloud without a `pullRequest=` or `branch=` parameter, so on a PR it shows the default branch. Add the parameter. Also fix the "0/N Quality Gates passed" message shown when `SONAR_ISSUE_RETRIEVAL` is not set. | [ci.yml:698-701](.github/workflows/ci.yml#L698-L701), [:773](.github/workflows/ci.yml#L773) | M | | A PR with a failing gate shows that failure in the report. |
| 2.5 | A failed `plan` job is not treated as a failure: SBOM still runs and the banner says "All Checks Passed". Add `plan` to the `needs` of `sbom` and `release-please` and to the banner check. | [ci.yml:547](.github/workflows/ci.yml#L547), [:573](.github/workflows/ci.yml#L573), [:756](.github/workflows/ci.yml#L756) | S | | Malformed `sonar-projects` input produces a failed banner and no SBOM job. |
| 2.6 | `hadolint-ignore` is documented as space-separated but the action expects commas. Convert spaces to commas before passing it. | [docker-lint.yml:110](.github/workflows/docker-lint.yml#L110), [:291](.github/workflows/docker-lint.yml#L291) | S | | `"DL3008 DL3009"` suppresses both rules. |
| 2.7 | `docker-exclude` patterns are expanded by the shell before matching. Disable globbing around the loop. | [ci.yml:491](.github/workflows/ci.yml#L491) | S | | `samples/*` excludes `samples/app1/Dockerfile`. |
| 2.8 | The secret scan cannot tell a Gitleaks crash from a finding (both exit 1). Use a distinct leak exit code, fall back to a single-commit scan when the "before" commit is missing after a force-push, and delete the unreachable line 128. | [secret-scanning.yml:97](.github/workflows/secret-scanning.yml#L97), [:128](.github/workflows/secret-scanning.yml#L128) | S | | A force-push does not produce a "0 secrets detected" failure. *The force-push failure was inferred from the code, not reproduced; reproduce it first.* |
| 2.9 | Two templates have a `with:` key containing only comments. Confirm whether GitHub rejects this, then comment out the key itself. | [license-compliance.yml:16](workflow-templates/license-compliance.yml#L16), [sbom.yml:13](workflow-templates/sbom.yml#L13) | S | | Both templates run unmodified in a test repository. *Not yet verified.* |
| 2.10 | Small defects: `DOCKERFILE` set to the context path; `artifact-retention-days` declared but unused in `sbom.yml`; `docker-context` and `docker-image-name` ignored unless `dockerfile` is set; Node detection can misfire on large repositories under `pipefail`. | [docker-lint.yml:421](.github/workflows/docker-lint.yml#L421), [sbom.yml:47](.github/workflows/sbom.yml#L47), [ci.yml:196-227](.github/workflows/ci.yml#L196-L227), [sonarcloud.yml:178](.github/workflows/sonarcloud.yml#L178) | S | | Each has a test or is removed. |
| 2.11 | Release Please (stays disabled): remove the dead inputs `changelog-path`, `changelog-types` and `version-file`; upload SBOMs with `gh release upload`, because `sbom-action` only attaches on release events or tag refs; add a token input for a GitHub App, because releases and PRs created with the default token do not trigger other workflows. Leave the `false &&` guard in place. | [release-please.yml:90](.github/workflows/release-please.yml#L90), [:182-183](.github/workflows/release-please.yml#L182-L183), [:215-233](.github/workflows/release-please.yml#L215-L233), [ci.yml:555](.github/workflows/ci.yml#L555) | M | | Works end to end in a sandbox repository with the guard removed locally; guard still present on `main`. |
| 2.12 | Bring the README in line with the code changed in Phases 1 and 2 (it still names the retired `sonarcloud-github-action`, if present, and documents inputs that change here). | [README.md](README.md) | S | | README matches the code. |

## Phase 3 — Version upgrades

Upgrade in small groups, one pull request each, and test in the sandbox repository (item 4.3) before merging. Versions are the latest releases as of 23 November 2026.

| ID | Action or tool | From | To | Note | Size | Owner |
|---|---|---|---|---|---|---|
| 3.1 | `anchore/scan-action` | v3 | v7.4.2 | Four majors; check input and output names. | M | |
| 3.2 | Gitleaks | v8.18.4 | v8.30.1 | `detect` is deprecated since v8.19; switch to `gitleaks git`. | S | |
| 3.3 | `actions/attest-sbom` | v3 | `actions/attest` v4.2.2 | `attest-sbom` is deprecated; inputs are compatible. | S | |
| 3.4 | `googleapis/release-please-action` | v4 | v5.0.0 | Do together with 2.11. | S | |
| 3.5 | `actions/checkout`, `download-artifact`, `setup-node`, `setup-python`, `setup-java`, `stale`, `dependency-review-action` | v6, v7, v6, v6, v5, v10, v4 | v7.0.1, v8.0.2, v7.1.0, v7.1.0, v6.3.0, v11.0.0, v5.0.1 | Read each major's release notes. | M | |
| 3.6 | `docker/setup-buildx-action`, `hadolint/hadolint-action`, `aquasecurity/trivy-action` | v3, v3.1.0, v0.35.0 | v4.4.1, **v3.1.0 (held)**, v0.36.0 | `trivy-action` v0.35.0 was the one tag not hijacked in the March 2026 incident; the upgrade is routine, not urgent. **Hadolint held at v3.1.0 (Hadolint 2.12) in v1:** v3.5.0 ships Hadolint 2.15, whose new rules (e.g. DL3066 "non-numeric user-id", which flags `USER node`) would newly fail lint in caller repos. Adopt in `v2` with a default ignore list or communicated rule change. | S | |
| 3.7 | `EndBug/label-sync` | v2 (last release February 2024) | Decide: keep, or replace with a short `gh label` script. | It declares the removed Node 20 runtime and now runs remapped on Node 24. | S | |

Already current, no action: `actions/upload-artifact@v7`, `github/codeql-action@v4`, `SonarSource/sonarqube-scan-action@v8.5.0`, `sonarqube-quality-gate-action@v1.2.1`.

## Phase 4 — Guard rails

| ID | Item | Size | Owner | Done when |
|---|---|---|---|---|
| 4.1 | Add a pull-request check on this repository that runs `actionlint` and `zizmor` over all workflows and templates. | S | | A PR with an expression pasted into a `run:` script fails the check. |
| 4.2 | Add `timeout-minutes` to every job. Only one step in the repository sets it today, and the default is six hours. | S | | Every job has a timeout. |
| 4.3 | Create a sandbox caller repository with a small Node app, a small Python app and two Dockerfiles. It calls the workflows from a branch, so changes are tested end to end before the tag moves. | M | | A PR to this repository can be exercised against the sandbox. |
| 4.4 | Write the release procedure: how a change is reviewed, tested in the sandbox, tagged, and how the `v1` tag is moved. | S | | Procedure committed to `CONTRIBUTING.md`. |

## Phase 5 — Release `v1` and move callers off `main`

| ID | Item | Size | Depends on | Owner | Done when |
|---|---|---|---|---|---|
| 5.1 | Change the orchestrator's internal references from `...@main` to same-repository relative paths (`./.github/workflows/<file>.yml`), so the orchestrator and its children always come from the same commit. *Confirm in the sandbox that relative paths resolve correctly when the orchestrator is called from another repository.* | S | 4.3 | | [ci.yml:298](.github/workflows/ci.yml#L298), [:318](.github/workflows/ci.yml#L318), [:338](.github/workflows/ci.yml#L338), [:525](.github/workflows/ci.yml#L525), [:562](.github/workflows/ci.yml#L562), [:582](.github/workflows/ci.yml#L582) no longer mention `@main`. |
| 5.2 | *Settings:* add a tag ruleset covering `v*` that restricts who can create, move and delete tags. | S | | | Ruleset active. |
| 5.3 | Tag `v1.0.0` and create the moving `v1` tag. Publish release notes. | S | Phases 1 to 4, 5.1, 5.2 | | Both tags exist. |
| 5.4 | Point every template and README example at `@v1`. | S | 5.3 | | No template references `@main`. |
| 5.5 | Publish a caller migration note: change `@main` to `@v1`, add the `permissions:` block from the template, pass named secrets. Callers are migrated by their own teams; `main` keeps working meanwhile. | S | 5.4 | | Note published and announced. |
| 5.6 | *Settings:* flip the org default workflow token to read-only. **Gate:** do this only after callers have explicit `permissions:` blocks. A caller without one will fail at start-up, because the called workflows request write scopes the read-only default does not grant. Before flipping, search the org for workflows with no `permissions:` key and review each. | M | 5.5 and caller migration | | Org setting is read-only and the pre-check list is empty or accepted. |

## Phase 6 — `v2`: fewer jobs, fewer billed minutes

**Baseline:** in a measured monorepo run (four Sonar projects, three Dockerfiles) the orchestrator billed 14 minutes for 475 seconds of compute. **Target:** 8 minutes or fewer for a full run, and 5 or fewer for a pull request touching one project. These targets are estimates from measured job durations.

| ID | Item | Size | Depends on | Owner | Done when |
|---|---|---|---|---|---|
| 6.1 | **Design first.** Settle how shared steps are packaged. A reusable workflow is always its own job, so merging jobs means composite actions or inline steps. Constraint: inside a reusable workflow called from another repository, `uses: ./...` on a step resolves to the *caller's* checkout, not this repository, so composite actions must be referenced by full path and tag. Write the chosen approach down and prove it in the sandbox. | M | 4.3 | | Short design note committed; sandbox run green. |
| 6.2 | Add one stable final job, `CI gate`, that fails if any needed job failed. Callers require only this check, so later restructuring never touches their branch protection again. Merge the CI Report into it and remove the report's Sonar polling loop ([ci.yml:689](.github/workflows/ci.yml#L689)). | M | 6.1 | | One required check name, documented. |
| 6.3 | Merge plan, secret scan and licence check into one "fast checks" job. They total about 28 seconds and bill 3 minutes today. | M | 6.1 | | Three jobs become one. |
| 6.4 | Lint all Dockerfiles in one job instead of one job each, installing Hadolint once and pulling Checkov once. | M | 6.1 | | Docker lint bills one minute regardless of Dockerfile count in the sandbox. |
| 6.5 | SonarCloud change detection: on pull requests scan only projects whose `base-dir` has changed files; on the main branch scan all. | M | 6.3 | | A PR touching one project starts one Sonar leg. |
| 6.6 | Gate by event. Schedule: full-history secret scan, licence check, and image CVE scan when image build is on; skip Sonar and Docker lint. Release: SBOM only. | S | | | Scheduled and release runs start only those jobs. |
| 6.7 | Fix the templates' triggers: `push` only on the main branch, `pull_request` for everything else, plus a `concurrency` group with cancel-in-progress. Today a develop-to-main PR runs twice per commit ([ci.yml:17-26](workflow-templates/ci.yml#L17-L26)). **Moved into the Phase 5 pull request:** templates only, so it is not a `v2` change. | S | | | One run per commit on a PR. |
| 6.8 | Skip heavy jobs for documentation-only changes, decided inside the fast-checks job so required checks still report. | S | 6.3 | | A README-only PR completes with the gate green and no Sonar or Docker jobs. |
| 6.9 | Image-build path (opt-in): use the buildx GitHub cache; run scan, SBOM and Dive in the build job instead of passing a tarball between four jobs; scan once with Trivy and convert formats. | L | 6.1 | | One job; one Trivy scan per image. |
| 6.10 | Change the stale template from daily to weekly ([stale.yml:6](workflow-templates/stale.yml#L6)). **Moved into the Phase 5 pull request.** | S | | | Cron is weekly. |
| 6.11 | Optional: add a `light-runner` input so the fast-checks and gate jobs can use `ubuntu-slim`. *Its price and limits (no Docker, 15-minute cap) come from third-party pricing pages; confirm against GitHub's docs first.* | S | 6.2, 6.3 | | Input exists and is documented, or the item is closed as not worthwhile. |
| 6.12 | Tag `v2.0.0` and `v2`. Publish a migration note that lists the removed check names and the single `CI gate` check to require instead. State how long `v1` will receive fixes. | S | 6.2 to 6.10 | | Tags and note published. |
| 6.13 | Measure. Re-run the sandbox and one real caller on `v2` and record billed minutes against the baseline. | S | 6.12 | | Numbers recorded in this file. |

## Phase 7 — Enhancements (after `v2`)

| ID | Item | Size | Owner |
|---|---|---|---|
| 7.1 | Add a dependency vulnerability scan to the fast-checks job (Trivy filesystem scan). Today the orchestrator has no CVE scan unless image build is enabled, and GitHub's dependency review is not available on private repositories on the Team plan. | M | |
| 7.2 | Upload Gitleaks results as SARIF where code scanning is available (public repositories on this plan). | S | |
| 7.3 | Extract the Sonar coverage artifact into its own directory instead of over the checkout ([sonarcloud.yml:212-218](.github/workflows/sonarcloud.yml#L212-L218)). | S | |
| 7.4 | Run OpenSSF Scorecard on this repository. | S | |
| 7.5 | Document that Dependabot pull requests receive no Actions secrets, so the Sonar job fails on them unless Dependabot secrets are configured or the job is skipped for that actor. | S | |
| 7.6 | Build provenance and SBOM attestation by default when images are built. *Conditional on plan; see below.* | M | |

---

## What the Team plan limits

- **Code scanning (SARIF upload):** public repositories only. The workflows already probe for it and skip the upload when unavailable, so nothing breaks; findings on private repositories are visible only in the run summary and artifacts.
- **Dependency review:** not available on private repositories. The `dependency-review.yml` template only works on public ones. Item 7.1 is the substitute.
- **Secret scanning and push protection:** free on public repositories (item 0.4). On private repositories they need a paid add-on, so Gitleaks remains the control there.
- **Artifact attestations on private repositories:** believed to need GitHub Enterprise Cloud. Confirm before starting 7.6.
- **Included minutes:** 3,000 a month on Team. One busy private repository reviewed alongside this work used about 2,150 in 30 days.

## Assumptions to verify during the work

| Claim | Status | Checked in item |
|---|---|---|
| A `with:` key holding only comments makes a workflow invalid. | Likely, not tested. | 2.9 |
| A force-push causes a false secret-scan failure. | Inferred from the code. | 2.8 |
| With an empty forbidden list, AGPL dependencies pass the licence gate. | Mechanism confirmed; effect on Trivy's classification not run. | 2.2 |
| Relative `./.github/workflows/...` references resolve to this repository when the orchestrator is called from elsewhere. | Expected from GitHub's documentation; not tested here. | 5.1 |
| `ubuntu-slim` price and limits. | Third-party sources only. | 6.11 |
| Node 20 was removed from runners on 23 September 2026. | Secondary sources only. | 3.7 |

## Known follow-ups outside this roadmap

These were found during the review but belong to other repositories.

- **Caller repositories (18):** move from `@main` to `@v1`, add `permissions:`, pass named secrets, then adopt `v2` and require the single `CI gate` check.
- **Diriyah-AI-Platform-Tracker:** runs its own inline pipeline. 58 of 75 push runs in 30 days duplicated a pull-request run on the same commit (866 billed minutes); nine sub-minute jobs billed 987 minutes for about 250 minutes of work; the infrastructure workflow bills a minute per job to skip every step; the nightly schedule on `development` is not gated; the web tests average 226 seconds.
- **ArchAtlas:** the 12 most recent runs, back to 26 August 2026, all failed or were cancelled.

## References

- [Trivy supply-chain advisory GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23)
- [GitHub changelog: Actions policy supports SHA pinning](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)
- [GitHub Well-Architected: Actions security](https://wellarchitected.github.com/library/application-security/recommendations/actions-security/)
- [Trivy licence scanning](https://trivy.dev/docs/latest/scanner/license/)
- [Trivy discussion #6684: licences for npm and pip](https://github.com/aquasecurity/trivy/discussions/6684)
- [GitHub changelog: deprecation of Node 20 on Actions runners](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)
