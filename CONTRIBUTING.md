# Contributing to Orion Digital Solutions

Thank you for your interest in contributing to our projects! We welcome contributions across our areas of focus: **Data & Analytics, AI & Machine Learning, Robotic Process Automation, Software Engineering,** and **Automation**.

Please take a moment to review this guide before submitting a contribution.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Branch Naming Conventions](#branch-naming-conventions)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Development Standards](#development-standards)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

---

## Code of Conduct

By participating in any of our projects, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

---

## Getting Started

1. **Fork** the repository you want to contribute to.
2. **Clone** your fork locally.
3. **Create a branch** from `main` for your changes (see [Branch Naming Conventions](#branch-naming-conventions)).
4. **Make your changes** following our [Development Standards](#development-standards).
5. **Test** your changes thoroughly before submitting.
6. **Open a Pull Request** against the `main` branch.

---

## How to Contribute

### Reporting Bugs

Use the **Bug Report** issue template. Include:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected vs. actual behavior
- Environment details (OS, language/framework version, etc.)
- Relevant logs or screenshots

### Suggesting Features or Enhancements

Use the **Feature Request** issue template. Include:
- The problem you are trying to solve
- A description of the proposed solution
- Any alternatives you have considered

### Submitting Code Changes

- Keep PRs focused — one feature or fix per PR
- Include relevant tests for new functionality
- Update documentation if your change affects behavior
- Ensure all CI checks pass before requesting review

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

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples:**
```
feat(ml-pipeline): add SHAP explainability to classification model
fix(rpa-bot): handle timeout exception in invoice processing workflow
docs(api): update endpoint reference for v2 data export
```

---

## Pull Request Process

1. Ensure your branch is up to date with `main` before opening a PR.
2. Fill out the pull request template completely.
3. Assign at least one reviewer from the relevant team.
4. Address all review comments before merging.
5. PRs require **at least one approving review** before merge.
6. Squash commits where appropriate to maintain a clean history.
7. Delete the source branch after merging.

---

## Development Standards

### General

- Write clean, readable, and self-documenting code
- Follow the language/framework style guide for the project (PEP 8 for Python, ESLint config for JS/TS, etc.)
- Do not commit secrets, credentials, API keys, or environment-specific configuration
- Use `.env` files (gitignored) for local secrets; use GitHub Secrets for CI/CD

### Data & Analytics / AI / ML Projects

- Document data sources, transformations, and model assumptions
- Pin dependency versions (`requirements.txt`, `pyproject.toml`, `package-lock.json`)
- Include reproducibility instructions (seeds, environment specs)
- Store large datasets and model artifacts outside the repository (cloud storage, DVC, etc.)

### RPA / Automation Projects

- Test automations against sandbox/UAT environments before merging
- Document process maps and exception-handling logic
- Avoid hardcoding credentials or environment-specific paths

### Software Engineering

- Write unit tests for all new business logic
- Maintain test coverage at or above the project's established threshold
- Follow API versioning conventions for any public-facing endpoints

---

## Questions?

If you have questions not covered here, open a [Discussion](../../discussions) in the relevant repository or visit [www.orion360.com](https://www.orion360.com/) to contact us.
