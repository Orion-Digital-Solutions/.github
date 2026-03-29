# Governance — Orion Digital Solutions `.github`

This document describes how the `.github` repository is governed: who owns it, how changes are approved, and how project repositories interact with the shared pipelines it provides.

---

## Table of Contents

- [Purpose and Scope](#purpose-and-scope)
- [Roles and Responsibilities](#roles-and-responsibilities)
- [Decision-Making Process](#decision-making-process)
- [Change Approval by Area](#change-approval-by-area)
- [How Repositories Opt In and Out](#how-repositories-opt-in-and-out)
- [Release Authority](#release-authority)
- [Escalation Path](#escalation-path)

---

## Purpose and Scope

This repository (`orion-digital-solutions/.github`) is the **engineering standards and shared CI/CD hub** for the entire Orion Digital Solutions GitHub organization. It serves as the single source of truth for:

- **Reusable CI/CD workflows** (`.github/workflows/`) — changes here take effect immediately for every project repository that calls them.
- **Workflow starter templates** (`workflow-templates/`) — copied into new project repositories to bootstrap CI.
- **Org-wide community health files** — `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `PULL_REQUEST_TEMPLATE.md`, and issue templates. GitHub automatically surfaces these in any org repository that does not define its own.
- **Public org profile** (`profile/README.md`) — rendered on the organization's GitHub landing page.

Because changes to reusable workflows propagate automatically to all consuming repositories **without any action on their part**, this repository carries the highest change-blast-radius in the organization. Its governance is correspondingly stricter than a typical project repository.

---

## Roles and Responsibilities

| Role | GitHub Team | Responsibilities |
|------|-------------|-----------------|
| **DevOps / Platform** | `@orion-digital-solutions/devops` | Own and maintain all CI/CD reusable workflows and workflow templates. Review pipeline changes, pin action versions, monitor for breakage across consuming repositories. |
| **Engineering Leads** | `@orion-digital-solutions/engineering-leads` | Own governance documents, community health files, and issue/PR templates. Approve any change that affects org-wide contributor experience. Co-own pipeline changes with DevOps. |
| **Security Team** | `@orion-digital-solutions/security` | Own `SECURITY.md` and all security-scanning workflow inputs. Must approve changes to secret-scanning, license-compliance, SBOM, or dependency-review configurations. |
| **Marketing** | `@orion-digital-solutions/marketing` | Own `profile/README.md`. Co-own with Engineering Leads for tone and messaging consistency. |
| **Org Admins** | GitHub organization owners | Hold final authority on branch protection rules, team membership, and org-level secrets. Approve changes that require elevated permissions (e.g. adding a new org secret). |

CODEOWNERS in this repository enforces required reviews automatically. See [CODEOWNERS](CODEOWNERS) for the path-to-team mapping.

---

## Decision-Making Process

### Routine changes

> Bug fixes, version pin bumps, documentation corrections, message copy edits.

1. Open a PR against `main` from a feature branch (`fix/`, `docs/`, `chore/` prefix).
2. One approving review from the relevant CODEOWNERS team is sufficient.
3. Merge using **squash and merge** with a [Conventional Commit](CONTRIBUTING.md#commit-message-guidelines) title.

### Significant changes

> New inputs to existing workflows, behavior changes to existing jobs, new reusable workflows, changes to community health files, changes to issue/PR templates.

1. Open an issue first to describe the problem and proposed change. Tag the relevant teams.
2. Allow **48 hours** for async feedback before opening a PR.
3. PR requires **two approving reviews**: one from `@orion-digital-solutions/devops` or `@orion-digital-solutions/engineering-leads` (depending on area) and one from any other team member.
4. PR description must state: *which repositories are affected*, *what the behavior change is*, and *how consuming repositories can override the new behavior if needed*.

### Breaking changes

> Removing or renaming workflow inputs, changing default values in a way that alters existing consumers, removing a reusable workflow entirely.

1. Open an issue with the `breaking-change` label. Notify engineering leads directly.
2. Post advance notice in the engineering Slack channel (or equivalent) at least **one week before** the PR is merged.
3. PR requires approval from **an org admin** in addition to the normal reviewers.
4. The PR description must include a migration guide for all consuming repositories.
5. If possible, keep the old input as a deprecated no-op for one release cycle before removing it.

---

## Change Approval by Area

| Area | Required Reviewers | Change Class |
|------|-------------------|-------------|
| `.github/workflows/` | `@orion-digital-solutions/devops` + `@orion-digital-solutions/engineering-leads` | Significant or Breaking |
| `workflow-templates/` | `@orion-digital-solutions/devops` + `@orion-digital-solutions/engineering-leads` | Significant |
| `SECURITY.md` | `@orion-digital-solutions/security` | Significant |
| `CODE_OF_CONDUCT.md` | `@orion-digital-solutions/engineering-leads` | Significant |
| `CONTRIBUTING.md` | `@orion-digital-solutions/engineering-leads` | Routine or Significant |
| `SUPPORT.md` | `@orion-digital-solutions/engineering-leads` | Routine |
| `PULL_REQUEST_TEMPLATE.md` | `@orion-digital-solutions/engineering-leads` | Routine |
| `ISSUE_TEMPLATE/` | `@orion-digital-solutions/engineering-leads` | Routine |
| `profile/README.md` | `@orion-digital-solutions/marketing` + `@orion-digital-solutions/engineering-leads` | Routine |
| `GOVERNANCE.md` (this file) | `@orion-digital-solutions/engineering-leads` + org admin | Breaking |

---

## How Repositories Opt In and Out

### Opting in to the shared CI pipeline

Copy the starter template from `workflow-templates/ci.yml` into your repository at `.github/workflows/ci.yml` and set the required inputs. The full process is documented in the [README Quick Start](README.md#quick-start--adding-ci-to-a-new-repository).

### Opting out of the shared CI pipeline

Delete or stop calling the relevant reusable workflow from your repository's caller workflow. The shared workflows only run when a repository explicitly calls them — they are never pushed into repositories without consent.

### Overriding a community health file

Create the file at the same path inside your project repository. GitHub gives precedence to repository-level files over org-level defaults. For example, creating `CONTRIBUTING.md` at the root of `my-repo` means GitHub will show that file instead of the one in this `.github` repository.

### Overriding workflow behavior per repository

Every reusable workflow exposes documented inputs. Pass non-default values at the call site:

```yaml
jobs:
  ci:
    uses: orion-digital-solutions/.github/.github/workflows/ci.yml@main
    with:
      forbidden-licenses: "GPL-3.0,AGPL-3.0"   # narrower than the org default
      secret-scan-full-history: true
    secrets: inherit
```

See the [Orchestrator Input Reference](README.md#orchestrator-input-reference) for the full list.

### Pinning to a specific version

By default, callers use `@main` and automatically receive all updates. To freeze a repository at a known-good version, pin to a tag or commit SHA:

```yaml
uses: orion-digital-solutions/.github/.github/workflows/ci.yml@v1.2.0
```

Note that pinned repositories no longer receive automatic security fixes. The DevOps team does not guarantee long-term support for pinned versions.

---

## Release Authority

This repository follows [Conventional Commits](CONTRIBUTING.md#commit-message-guidelines). Release Please manages versioning and changelog generation automatically.

| Version bump | Triggered by |
|---|---|
| **Patch** (`x.x.1`) | `fix:`, `perf:` commits |
| **Minor** (`x.1.0`) | `feat:` commits |
| **Major** (`1.0.0`) | `feat!:` commits or `BREAKING CHANGE:` footer |

Release PRs are opened automatically by the `release-please` workflow. **Only org admins may merge a Release PR** that contains a major version bump. Minor and patch releases may be merged by Engineering Leads.

---

## Escalation Path

| Situation | First contact | Escalation |
|-----------|--------------|-----------|
| A pipeline change broke a consuming repository | `@orion-digital-solutions/devops` | Engineering Leads → Org Admin |
| A security vulnerability found in a shared workflow | `@orion-digital-solutions/security` (private, via [SECURITY.md](SECURITY.md)) | Org Admin |
| Disagreement on a proposed change | Open a GitHub Discussion in this repository | Engineering Leads mediate; Org Admin has final say |
| A repository needs an exemption from an org default | Open an issue with the `governance` label | Engineering Leads review |

---

*For questions about this repository or its governance, open an issue or reach out via [www.orion360.com](https://www.orion360.com/).*
