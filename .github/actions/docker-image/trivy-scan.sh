#!/usr/bin/env bash
# Scans the image ONCE with Trivy, then derives every format from that JSON
# with `trivy convert` (ROADMAP 6.9):
#   table  filtered by SEVERITY, drives pass/fail via EXIT_CODE   (v1 "table" step)
#   json   filtered by SEVERITY -> docker-vuln-report.json        (v1 "JSON report" step)
#   sarif  all severities                                          (v1 "SARIF" step: trivy-action
#                                                                    drops the severity filter for
#                                                                    SARIF unless limit-severities-for-sarif)
# Unfixed CVEs are dropped at scan time (`convert` has no such filter), as v1
# did for all three outputs.
#
# Env:  TRIVY_BIN, WORK_DIR, IMAGE_NAME, SEVERITY, EXIT_CODE, IGNORE_UNFIXED, SHA
# Out:  <WORK_DIR>/trivy.sarif, <WORK_DIR>/report/docker-vuln-report.json
#       GITHUB_OUTPUT  result=pass|fail|error, vuln-count, sarif, report-dir
set -uo pipefail

SEVERITY=$(printf '%s' "${SEVERITY}" | tr -d '[:space:]')
FULL="${WORK_DIR}/trivy-full.json"
FILTERED="${WORK_DIR}/trivy-report.json"
SARIF="${WORK_DIR}/trivy.sarif"
REPORT_DIR="${WORK_DIR}/report"
mkdir -p "${REPORT_DIR}"

RESULT=pass
SCAN_ARGS=(image --image-src docker --scanners vuln,secret,misconfig
           --list-all-pkgs=false --exit-code 0 --format json --output "${FULL}")
[ "${IGNORE_UNFIXED}" = "true" ] && SCAN_ARGS+=(--ignore-unfixed)

echo "::group::Trivy scan (JSON, all severities)"
if ! "${TRIVY_BIN}" "${SCAN_ARGS[@]}" "${IMAGE_NAME}"; then
  echo "::error::Trivy could not scan ${IMAGE_NAME}."
  RESULT=error
fi
echo "::endgroup::"

if [ "${RESULT}" = pass ]; then
  if ! "${TRIVY_BIN}" convert --quiet --format json --list-all-pkgs=false \
         --severity "${SEVERITY}" --output "${FILTERED}" "${FULL}"; then
    echo "::error::trivy convert (json) failed."
    RESULT=error
  fi
fi

if [ "${RESULT}" = pass ]; then
  # The table is the human-readable verdict, as in v1. Its exit status is
  # EXIT_CODE when findings at SEVERITY remain (convert succeeded above, so a
  # non-zero status here is a finding, not a crash).
  "${TRIVY_BIN}" convert --quiet --format table --scanners vuln,secret,misconfig \
    --severity "${SEVERITY}" --exit-code "${EXIT_CODE}" "${FULL}"
  rc=$?
  if [ "${rc}" -ne 0 ]; then
    RESULT=fail
  fi
  if ! "${TRIVY_BIN}" convert --quiet --format sarif --output "${SARIF}" "${FULL}"; then
    echo "::warning::trivy convert (sarif) failed; no Trivy SARIF upload."
    rm -f "${SARIF}"
  fi
fi

# ── docker-vuln-report.json (v1 schema, read by the CI report) ─────────────
[ -s "${FILTERED}" ] || echo '{"Results":[]}' > "${FILTERED}"
VULN_COUNT=$(jq '[.Results[]?.Vulnerabilities // [] | length] | add // 0' "${FILTERED}" 2>/dev/null || echo "0")
jq -n \
  --slurpfile raw        "${FILTERED}" \
  --arg        image_name "${IMAGE_NAME}" \
  --arg        sha        "${SHA}" \
  --arg        severity   "${SEVERITY}" \
  --argjson    vuln_count "${VULN_COUNT}" \
  '{
    meta: {
      image:               $image_name,
      sha:                 $sha,
      severity_filter:     $severity,
      vulnerability_count: $vuln_count
    },
    results: $raw[0].Results
  }' > "${REPORT_DIR}/docker-vuln-report.json"

if [ "${RESULT}" = fail ]; then
  echo "::error::Trivy: ${VULN_COUNT} vulnerability/vulnerabilities at severity ${SEVERITY}. Review the 'docker-vuln-report' artifact or GitHub Security tab."
fi
{
  echo "result=${RESULT}"
  echo "vuln-count=${VULN_COUNT}"
  [ -s "${SARIF}" ] && echo "sarif=${SARIF}"
  echo "report-dir=${REPORT_DIR}"
} >> "${GITHUB_OUTPUT}"
echo "Trivy result: ${RESULT} (${VULN_COUNT} vulnerabilities at ${SEVERITY})"
exit 0
