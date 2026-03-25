# Security Policy

## Our Commitment

Orion Digital Solutions takes security seriously. We hold **CyberVadis Platinum Status** and are committed to maintaining the security and integrity of all our software, data pipelines, and automation solutions. We appreciate responsible disclosure from the security community.

---

## Supported Versions

Security fixes are applied to the latest stable release of each project. The table below reflects our general support policy:

| Version | Supported |
|---|---|
| Latest release | ✅ Actively supported |
| Previous minor release | ✅ Security patches only |
| Older releases | ❌ Not supported — please upgrade |

Refer to individual repository documentation for project-specific version support.

---

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in any Orion Digital Solutions project, please report it responsibly by contacting us directly:

- **Website:** [www.orion360.com](https://www.orion360.com/)
- **Subject line:** `[SECURITY] <brief description>`

### What to Include in Your Report

To help us triage and resolve the issue quickly, please provide:

1. **Description** — A clear explanation of the vulnerability and its potential impact
2. **Affected component** — Repository name, module, or service
3. **Steps to reproduce** — Detailed steps or proof-of-concept (PoC)
4. **Environment** — OS, runtime version, dependency versions, and any relevant configuration
5. **Suggested fix** *(optional)* — If you have a proposed remediation

---

## Response Process

| Step | Target Timeframe |
|---|---|
| Acknowledgement of report | Within 3 business days |
| Initial triage and severity assessment | Within 7 business days |
| Status update to reporter | Within 14 business days |
| Resolution / patch release | Dependent on severity (see below) |

### Severity-Based Resolution Targets

| Severity | Target Resolution |
|---|---|
| Critical | 7 days |
| High | 14 days |
| Medium | 30 days |
| Low | Next scheduled release |

---

## Responsible Disclosure Policy

We ask that you:

- Give us reasonable time to investigate and remediate before any public disclosure
- Avoid accessing, modifying, or deleting data that does not belong to you
- Do not perform denial-of-service attacks, spam, or social engineering against our systems
- Do not disclose the vulnerability to others until it has been resolved

In return, we commit to:

- Acknowledging your report promptly
- Keeping you informed of our progress
- Not pursuing legal action against researchers who follow this policy in good faith
- Recognizing your contribution (with your permission) after the issue is resolved

---

## Scope

This policy covers vulnerabilities in:

- Source code in repositories under the [Orion Digital Solutions GitHub organization](https://github.com/orion-digital-solutions)
- APIs and services developed and maintained by Orion Digital Solutions
- Data pipeline and automation tooling published by Orion Digital Solutions

This policy does **not** cover:

- Third-party libraries or dependencies (report these to the upstream project)
- Infrastructure not owned or operated by Orion Digital Solutions
- Social engineering or phishing attempts targeting our employees

---

## Security Best Practices for Contributors

When contributing to our projects:

- **Never commit secrets** — no API keys, passwords, tokens, or credentials in code or config files
- Use **environment variables** or a secrets manager for sensitive configuration
- **Pin dependencies** and review them for known CVEs before adding
- Enable **Dependabot** or equivalent for automated dependency alerts
- Report any accidentally committed secrets immediately so they can be rotated
