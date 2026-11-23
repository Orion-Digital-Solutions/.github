# v2 design: packaging and job graph (ROADMAP 6.1)

Status: proposed, 23 November 2026. Covers ROADMAP items 6.1 to 6.8; 6.9 (image path) is only placed in the graph.

## 1. Decision

**Package every shared step sequence as a composite action under `.github/actions/<name>/` in this repository, and reference it with the self-repository prefix `uses: $/.github/actions/<name>`, from the orchestrator, from the standalone reusable workflows, and from other composite actions.**

`$/` was released on 30 July 2026 and does exactly what 6.1 needs: inside a reusable workflow called from another repository it resolves to *this* repository at the *running commit*, without a checkout. The constraint in the roadmap ("`uses: ./...` resolves to the caller's checkout") is still true for `./`, but `$/` removes it.

Fallback if the sandbox disproves `$/` (section 8): option (b), with the same composite actions. Only the `uses:` lines change.

## 2. Evidence

| Claim | Source |
|---|---|
| `$/` resolves to the workflow's own repository "at the exact commit that is running, with no checkout required", and "works everywhere the workspace-relative `./` syntax works, including workflow steps, composite action steps, nested composition, and reusable workflow calls". Needs runner 2.336.0 or newer. github.com only. | [Changelog, 2026-07-30](https://github.blog/changelog/2026-07-30-reference-same-repository-actions-with-self-repository-syntax/) |
| "`$/` always resolves against the repository of the file it appears in, not the repository that called it. ... a `$/` reference in the called workflow resolves to the called workflow's repository." It must not carry `@ref`. `./` "resolves against the runner's workspace". | [Workflow syntax: steps[*].uses](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#example-using-an-action-in-the-same-repository-as-the-workflow-at-the-running-commit-recommended) |
| Composite actions may use `$/` for sibling actions in their own repository. | [Metadata syntax: runs.steps[*].uses](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax) |
| `$/.github/workflows/x.yml` is the recommended way to call a same-repository reusable workflow; same commit as the caller workflow. | [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) |
| `job.workflow_ref`, `job.workflow_sha`, `job.workflow_repository`, `job.workflow_file_path` exist (github.com only); the docs' own example checks out the reusable workflow's repository at `job.workflow_sha`. `github.job_workflow_sha` does **not** exist (only the OIDC claim `job_workflow_sha` does). `job` is allowed in `steps.with`, not in `runs-on`. | [Contexts reference: job context](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#job-context); [Changelog, 2026-09-03](https://github.blog/changelog/2026-09-03-github-actions-early-september-2026-updates/) |
| A skipped job reports "Success" and does not block a merge even when it is a required check. | [Using conditions to control job execution](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions) |
| Check names of called jobs are `<caller job name> / <called job name>`. | Observed on `ci-sandbox` main today: `Orion CI / CI Report`, `Orion CI / Resolve CI plan`. |
| zizmor 1.32.0 (our pin) parses `$/` (since 1.29.0) and its `self-repository` audit flags `./` uses at help level: 6 findings on today's `ci.yml`. The PoC composites lint clean. | [zizmor audits: self-repository](https://docs.zizmor.sh/audits/#self-repository); local run of `zizmor 1.32.0 --offline` |
| actionlint 1.7.12 (latest, March 2026) rejects `$/` ("ref is missing" / "not following the format") and rejects `job.workflow_*` (strict `job` type). Fixes are open, unmerged. | [actionlint #760](https://github.com/rhysd/actionlint/issues/760), [#732](https://github.com/rhysd/actionlint/pull/732), [#757](https://github.com/rhysd/actionlint/issues/757), [#707](https://github.com/rhysd/actionlint/pull/707) |
| Hosted runner is at 2.338.2 (26 Oct 2026), above the 2.336.0 minimum. | [actions/runner releases](https://github.com/actions/runner/releases) |

## 3. Options compared

| | (a) `owner/.github/.github/actions/x@v2` | (b) checkout at `job.workflow_sha`, then `./.orion/...` | (c) inline steps in `ci.yml` | **(d) `$/.github/actions/x`** |
|---|---|---|---|---|
| Same commit as the running workflow | No. A caller pinned to `ci.yml@<sha>` still gets whatever `@v2` points to: caller SHA pinning is silently defeated. | Yes | Yes | Yes |
| Test from a branch | Must edit every internal `@v2` to the branch, then revert before merge; or a two-commit SHA dance. Easy to merge the wrong ref. | Works: sandbox points `ci.yml@<branch>` | Works | Works: sandbox points `ci.yml@<branch>`; nothing inside this repo changes |
| Integrity at runtime | Fine (downloaded at job start) | **Weak**: the action files sit in the caller's workspace. Any earlier step that runs caller code (licence `install-command`, npm install scripts) can rewrite them before a later `uses: ./.orion/...` loads them. | Fine | Fine: not read from the workspace (zizmor doc states it "can't load an action that was cloned at runtime") |
| Cost per job | None | +1 checkout (~2 to 3 s) | None | None |
| Single source for orchestrator and standalone workflows | Yes | Yes | **No**: about 600 lines of Gitleaks, Trivy, Hadolint and Checkov logic duplicated between `ci.yml` and the three standalone workflows, kept in sync by hand | Yes |
| actionlint 1.7.12 | OK | Errors on `job.workflow_*` (needs ignore) | OK | Errors on `$/` (needs ignore; loses input checking for those lines, see 6.1 tasks) |
| zizmor 1.32.0 | OK (`ref-pin` policy for our org) | `self-repository` help finding per `./` line | OK | OK |
| Other limits | Dependabot may try to bump our own `@v2` | GHES has no `job.workflow_*` (not relevant) | `run:` blocks near the 21k-character limit | Runner >= 2.336.0 (affects self-hosted labels passed in `runner`); not on GHES |

(d) is recommended: it is GitHub's documented, recommended mechanism, it keeps the orchestrator, its children and their actions on one commit, and it is the only option that is both testable from a branch without edits and immune to workspace tampering. Its only real cost is the actionlint gap, which is a lint-config line, not a runtime risk.

## 4. Composite actions (6.3, 6.4)

| Action | Replaces | Notes |
|---|---|---|
| `plan` | `plan` job script in `ci.yml` | Also does change detection, docs-only and event gating (sections 6, 7). Script shipped as `plan.sh` next to `action.yml`, run via `$GITHUB_ACTION_PATH`, so it is shellcheck-able and unit-testable. |
| `secret-scan` | `secret-scanning.yml` steps | Secrets are not visible to composites: `GITLEAKS_LICENSE` comes in as an input. (The Gitleaks CLI does not read it; propose deprecating it in v2. Confirm.) |
| `license-check` | `license-compliance.yml` steps | Runs `install-command`, the only step that executes caller code: always last in its job. |
| `docker-lint` | `docker-lint.yml` `lint` job | Takes the JSON target list. Uses the Hadolint binary (sha256-pinned, like Gitleaks) and one Checkov run over all files, instead of the per-file Docker-based actions. Adopts Hadolint 2.15 per ROADMAP 3.6. One SARIF per tool. |
| `docker-image` (6.9) | `docker-lint.yml` build/scan/SBOM/Dive jobs | Out of scope here. |

The standalone workflows (`secret-scanning.yml`, `license-compliance.yml`, `docker-lint.yml`) keep their inputs and job names and become one job each: checkout, then `uses: $/.github/actions/<name>`. The orchestrator's job-level calls change from `./.github/workflows/...` to `$/.github/workflows/...`.

## 5. v2 job graph (`ci.yml`)

All decisions about *what* runs are made once, in `fast-checks`, and exported as lists and counts. Downstream `if:` conditions only read counts.

| Job id | Name | needs | if |
|---|---|---|---|
| `fast-checks` | `Fast checks` | none | `github.event_name != 'release' \|\| inputs.docker-build-image` |
| `sonarcloud` | `SonarCloud (${{ matrix.proj.key }})` (calls `$/.github/workflows/sonarcloud.yml`) | `fast-checks` | `!cancelled() && needs.fast-checks.outputs.sonar-count > 0` |
| `docker-lint` | `Dockerfile lint` | `fast-checks` | `!cancelled() && needs.fast-checks.outputs.lint-count > 0` |
| `image` (6.9, opt-in) | `Image (${{ matrix.tgt.target-id }})` | `fast-checks` | `!cancelled() && needs.fast-checks.outputs.image-count > 0` |
| `release-please` | `Release Please` | `fast-checks, sonarcloud, docker-lint, image` | unchanged (still behind `false &&`) |
| `sbom` | `SBOM Generation` | `fast-checks, sonarcloud, docker-lint, image` | `always() && ((github.event_name == 'push' && github.ref_name == inputs.main-branch) \|\| github.event_name == 'release') && !contains(needs.*.result, 'failure') && !contains(needs.*.result, 'cancelled')` |
| `gate` | `CI gate` | every job above | `always()` |

`fast-checks` steps, in this order: checkout (`fetch-depth: 0`, no persisted credentials) → `plan` → `secret-scan` (`if: !cancelled() && event != release`) → `license-check` (same `if`) → upload one `ci-fast-checks` report artifact (`if: always()`). Its job outputs: `sonar-projects`, `sonar-count`, `lint-targets`, `lint-count`, `image-targets`, `image-count`, `docs-only`, and the outcomes of the three steps. Later steps cannot alter an earlier step's outcome or outputs, so putting `install-command` last keeps the secret-scan and plan verdicts trustworthy.

In YAML write these as `if: ${{ !cancelled() && ... }}`: a bare leading `!` is parsed as a YAML tag. `!cancelled()` on the downstream jobs keeps today's behaviour that a secret finding does not hide Sonar and lint results. If `plan` itself failed, the counts are empty and those jobs skip; the gate fails on `fast-checks`.

What each event starts (counts come from `plan`):

| Event | fast-checks | sonarcloud | docker-lint | image | sbom | gate |
|---|---|---|---|---|---|---|
| `pull_request` | delta secret scan, licence | changed projects only | all targets (optionally changed only, 6.4) | if build on | no | yes |
| `pull_request`, docs-only | delta secret scan, licence | no | no | no | no | yes |
| `push` to main branch | delta, licence | all | all | if build on | yes | yes |
| `push` other branch | delta, licence; docs-only applies | all | all | if build on | no | yes |
| `schedule` | full-history secret scan, licence | no | no | CVE scan only, if build on | no | yes |
| `release` | plan only, and only if build on | no | no | SBOM attach, if build on | yes | yes |

## 6. Sonar change detection (6.5)

Done in `plan.sh`, only on `pull_request`; every other event that scans Sonar scans all projects.

1. Changed files: `git diff --name-only --no-renames HEAD^1 HEAD` on the PR merge commit that `actions/checkout` checks out (first parent = current base), so the list is exactly what the PR changes. `--no-renames` lists both old and new paths. If the diff fails, or `HEAD` is not a merge commit, scan all projects (fail open).
2. A project is affected when any of these is true:
   - its `base-dir` is empty or `.` (a root project sees every change);
   - a changed path equals `base-dir` or starts with `base-dir/`;
   - a changed path matches one of the element's optional new `"paths"` globs (shared code outside `base-dir`, e.g. `"paths": ["packages/shared/*"]`);
   - a changed path matches a global trigger: `.github/workflows/*` or `sonar-project.properties` at the root.
3. Globs are bash `case` patterns with globbing off (same as `docker-exclude`): `*` also matches `/`.
4. `sonar-projects` output is the filtered list; `sonar-count` its length. Zero means the matrix job is skipped and the gate treats that as fine.

## 7. Docs-only detection (6.8)

Also in `plan.sh`, on `pull_request` and on `push` to branches other than the main branch (main always runs in full, so the Sonar baseline and SBOM stay current).

- `docs-only=true` when the changed-file list is non-empty and every path matches the new input `docs-only-paths` (newline-separated `case` patterns). Default: `*.md`, `*.mdx`, `*.rst`, `docs/*`, `LICENSE`, `LICENSE.*`, `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE*`, `CODEOWNERS`. Not `*.txt` (`requirements.txt`). An empty input disables the skip.
- Push base is `github.event.before`; when it is all zeros or not in the clone (new branch, force-push), `docs-only=false` and all projects scan.
- When true, `plan` sets the Sonar, lint and image counts to 0. Secret scan and licence still run (docs can leak secrets).
- No required check is left pending because callers require only `CI gate`, which always runs. Skipped jobs never create pending checks; they report skipped. This is why callers must stop requiring per-project or per-Dockerfile checks.

## 8. `CI gate` contract (6.2)

- Job id `gate`, name `CI gate`. With the template's caller job (`name: Orion CI`) the check is **`Orion CI / CI gate`**. This name is fixed for the life of v2; the README will say so. It is the only check callers should require.
- `if: always()`. Never `!cancelled()`: a skipped gate would count as a passing required check. A cancelled run fails the gate.
- Verdict, from job results only: fail if any needed job is `failure` or `cancelled`, or if `fast-checks` is `skipped` on an event other than `release`. Skipped jobs that `plan` gated off pass.
- The report (today's `report` job) moves into the gate as earlier `continue-on-error` steps. It never changes the verdict, and nothing it reads (artifacts, Sonar API) can make the gate green. The Sonar polling loop goes: each Sonar leg already waits for its Quality Gate, so the gate reads final results once, scoped by `pullRequest=`/`branch=` as today.
- Permissions: `contents: read`.

## 9. Billed minutes for the measured monorepo case

Inputs (measured): plan 5 s, secret 10 s, licence 13 s, Docker lint 28 to 37 s per file (3), Sonar 54 to 110 s per project (4, about 330 s total: one leg under 60 s, three over), report 20 s. Baseline: 14 billed minutes for 475 s.

| Run | Jobs (billed minutes) | Total |
|---|---|---|
| Baseline, any full run | plan 1, secret 1, licence 1, Docker 3, Sonar 1+2+2+2, report 1 | **14** |
| v2 PR or push, all projects | fast-checks 1 (about 30 s), docker-lint 1 (estimate 35 to 55 s: one checkout, one Hadolint install, one Checkov run), Sonar 7, gate 1 | **10** (+1 SBOM on main) |
| v2 PR touching one project | fast-checks 1, docker-lint 1 (0 if Dockerfile change detection is adopted and no Dockerfile changed), Sonar 1 or 2, gate 1 | **3 to 5** |
| v2 docs-only PR | fast-checks 1, gate 1 | **2** |
| v2 schedule | fast-checks 1 (full-history scan may run longer), gate 1, plus image jobs if build is on | **2** |
| v2 release | sbom 1, gate 1, plus image SBOM if build is on | **2** |

The roadmap target of 8 for a full run is not reachable by job merging alone: Sonar is 7 of the 10 minutes and its legs must stay separate (one Quality Gate each, parallel). Getting each leg under 60 s (cache `~/.sonar/cache` and the scanner JRE, skip unused `setup-*` steps) would make a full run 7. Merging Sonar into one sequential job saves 1 minute at about 4 minutes of wall time; not recommended.

## 10. What callers change

1. `ci.yml@v1` → `ci.yml@v2`. Keep the calling job's `name: Orion CI` (it is part of the check name).
2. Branch protection or ruleset: remove `Orion CI / Resolve CI plan`, `Orion CI / Secret Scanning / Gitleaks Secret Scan`, `Orion CI / License Compliance / OSS License Compliance`, `Orion CI / SonarCloud (<key>)`, `Orion CI / Docker (<id>) / ...`, `Orion CI / CI Report`. Add `Orion CI / CI gate`. Do not require SonarCloud's own per-project checks either: unscanned projects no longer post one.
3. `permissions:` block: unchanged.
4. Inputs: none removed. New, optional: `docs-only-paths`, and `"paths"` in `sonar-projects` elements. `GITLEAKS_LICENSE` becomes a no-op (pending confirmation).
5. Self-hosted runners passed through `runner:` must be on runner 2.336.0 or newer.
6. Behaviour changes for the migration note: Hadolint 2.15 rules (ROADMAP 3.6); Docker lint SARIF moves from per-target categories (`hadolint-dockerfile-<id>`) to one per tool, so public repos see the old categories' alerts go stale; PRs scan only changed Sonar projects.

## 11. Proof of concept and how to run it

Files: `.github/actions/v2-poc/action.yml` (outer), `.github/actions/v2-poc/inner/action.yml` and `inner/marker.txt` (inner). The outer action optionally plants a decoy copy of the inner action in the caller's workspace at the same path, calls the inner action with `uses: $/.github/actions/v2-poc/inner`, and fails unless the inner action returns `v2-poc-1`, the marker committed alongside the outer file.

**Run 1: composite called from another repository.** Push these files on a branch of this repository, for example `ci/v2-6.1-poc`. On a branch of `Orion-Digital-Solutions/ci-sandbox`, add:

```yaml
name: v2 packaging probe
on: workflow_dispatch
permissions: {}
jobs:
  probe:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: Orion-Digital-Solutions/.github/.github/actions/v2-poc@ci/v2-6.1-poc
        with:
          plant-decoy: "true"
```

Expect green, with the log line `OK: inner action returned 'v2-poc-1' from this commit.` A `decoy` value would mean `$/` read the workspace.

**Run 2: version skew.** Commit `v2-poc-2` into both `inner/marker.txt` and `WANT` on the branch. Run once with `@<first commit SHA>` and once with `@ci/v2-6.1-poc`. Both must pass, returning `-1` and `-2` respectively.

**Run 3: through a reusable workflow (the real v2 path).** Needs a workflow file, so it belongs in the 6.1 PR rather than here. Add `.github/workflows/v2-poc.yml` on the same branch:

```yaml
name: v2 packaging probe (reusable)
on:
  workflow_call:
permissions: {}
jobs:
  probe:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Show job.workflow_* (informational)
        env:
          WF_REPO: ${{ job.workflow_repository }}
          WF_SHA: ${{ job.workflow_sha }}
        run: echo "defined in ${WF_REPO}@${WF_SHA}"
      - uses: $/.github/actions/v2-poc
        with:
          plant-decoy: "true"
```

Call it from the sandbox with `uses: Orion-Digital-Solutions/.github/.github/workflows/v2-poc.yml@ci/v2-6.1-poc`. Expect green, and `WF_REPO` = `Orion-Digital-Solutions/.github`. Delete the PoC files when 6.3 lands.

## 12. Tasks that belong to the 6.1 PR

- `lint-workflows.yml`: add `.github/actions/**` to the path filters; pass `.github/actions/*/action.yml` and `.github/actions/*/*/action.yml` to zizmor; give actionlint `-ignore '^specifying action "\$/'` and `-ignore '^reusable workflow call "\$/'` until actionlint ships #732.
- `check_pinned_inputs.py`: treat `$/` like `./` (not "NOT PINNED"); check `with:` keys of `$/` uses against the local `action.yml` (replaces what actionlint loses); also scan `runs.steps` of composite `action.yml` files.
- `dependabot.yml`: `directories: ["/", "/.github/actions/*"]` so pins inside composites are updated.
- CONTRIBUTING: sandbox procedure unchanged (point `ci.yml@<branch>`); note that composites are tested through it.

## 13. Open questions for sandbox runs

1. Runs 1 to 3 above: `$/` from a private caller to this public repository, at a branch and at a SHA; nested `$/` inside a composite; decoy ignored.
2. Are a failed job's outputs available to `!cancelled()` dependants? (`fast-checks` failing on a secret must not hide Sonar.)
3. Exact check names in v2, including a skipped matrix job (today it shows as `SonarCloud (${{ matrix.proj.key }})`).
4. Does Dependabot parse workflows with `$/` lines without errors, and does the `directories` glob find composite actions?
5. Merged Docker lint with the sandbox's two Dockerfiles (and a third added for the test): does it stay under 60 s?
6. Sonar change detection cannot run in the sandbox (no Sonar project). Test on a real monorepo caller branch, per CONTRIBUTING.
7. Does any caller pass a self-hosted label in `runner`? If so, check its runner version.
