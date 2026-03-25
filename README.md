# Orion Organization Defaults (`.github`)

This repository contains organization-wide GitHub defaults for Orion, including community health files, issue/PR templates, and reusable workflow templates.

When a repository in the organization does not define its own community health files, GitHub uses the defaults from this repository.

## Repository Structure

```text
.github/
├── profile/
│   └── README.md                          (org profile page — already existed)
├── ISSUE_TEMPLATE/
│   ├── bug_report.md                      (structured bug report template)
│   ├── feature_request.md                 (feature request template with domain tags)
│   └── config.yml                         (disables blank issues, links to support)
├── workflow-templates/
│   ├── python-ci.yml + .properties.json   (lint + test across Python 3.10–3.12)
│   ├── node-ci.yml + .properties.json     (build + test across Node 18/20/22)
│   ├── dependency-review.yml + .json      (PR dep vulnerability scanning)
│   └── codeql-analysis.yml + .json        (weekly static security analysis)
├── CODE_OF_CONDUCT.md                     (community standards)
├── CONTRIBUTING.md                        (branch/commit conventions, dev standards per domain)
├── SECURITY.md                            (vuln reporting, response SLAs, CyberVadis ref)
├── SUPPORT.md                             (tiered support: community -> enterprise)
├── PULL_REQUEST_TEMPLATE.md               (structured PR checklist)
└── README.md                              (repo-level readme)
```

## What Lives Here

- `profile/README.md`: public organization profile content.
- `ISSUE_TEMPLATE/`: default issue forms/templates and issue creation behavior.
- `PULL_REQUEST_TEMPLATE.md`: default pull request checklist and guidance.
- `workflow-templates/`: reusable workflow templates and metadata for project bootstrap.
- `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`: default community health and governance docs.

## Usage Notes

- Add or update files here to set organization-wide defaults.
- Individual repositories can override any default by defining the same file locally.
- Keep templates and policies aligned with engineering/security standards.
