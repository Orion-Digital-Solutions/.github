#!/usr/bin/env bash
# Probes whether code scanning (SARIF upload) is available for this
# repository. Never fails: writes available=true|false to GITHUB_OUTPUT.
#
# Env:  GH_TOKEN, API_URL, REPO
set -uo pipefail

HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API_URL}/repos/${REPO}/code-scanning/alerts?per_page=1" || true)
if [ "${HTTP_CODE}" = "200" ]; then
  echo "available=true" >> "${GITHUB_OUTPUT}"
else
  echo "::warning::SARIF upload skipped — code scanning unavailable (HTTP ${HTTP_CODE:-none}). Enable GitHub Advanced Security or set upload-sarif: false to suppress this warning."
  echo "available=false" >> "${GITHUB_OUTPUT}"
fi
