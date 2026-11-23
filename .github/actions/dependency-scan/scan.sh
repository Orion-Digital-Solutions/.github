#!/usr/bin/env bash
# Trivy filesystem vulnerability scan of the checkout (ROADMAP 7.1). Scans
# ONCE to JSON, then derives every format from that JSON with `trivy convert`
# (same pattern as docker-image/trivy-scan.sh):
#   json   filtered by SEVERITY -> dependency-vuln-report.json (artifact)
#   table  filtered by SEVERITY, job log only
#   sarif  filtered by SEVERITY, only when WANT_SARIF is true
# The verdict is the vulnerability count of the filtered JSON, so the table,
# the report, the SARIF and the verdict always agree.
#
# Repository-controlled Trivy settings:
#   trivy.yaml   NOT read: Trivy auto-loads ./trivy.yaml, which could lower
#                the severity or skip directories; an empty --config is used.
#   .trivyignore (repository root, Trivy's default location) IS honoured, to
#                accept a CVE explicitly. On pull requests it is read from the
#                BASE branch, so a PR cannot ignore its own new vulnerability
#                (same rule as .gitleaksignore in secret-scan). A change to it
#                takes effect once merged.
#
# Env:  TRIVY_BIN, WORK_DIR, SCAN_PATH, SEVERITY, IGNORE_UNFIXED, WANT_SARIF,
#       SHA, EVENT_NAME, BASE_REF
# Out:  GITHUB_OUTPUT  status=ok|error, vuln-count, report-dir, sarif
#       (sarif only when produced). Always exits 0; the verdict step decides.
set -uo pipefail

SEVERITY=$(printf '%s' "${SEVERITY}" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
FULL="${WORK_DIR}/trivy-full.json"
FILTERED="${WORK_DIR}/trivy-filtered.json"
SARIF="${WORK_DIR}/trivy-dependencies.sarif"
REPORT_DIR="${WORK_DIR}/report"
EMPTY_CONFIG="${WORK_DIR}/trivy-empty.yaml"
IGNORE_FILE="${WORK_DIR}/trivyignore"
mkdir -p "${REPORT_DIR}"
: > "${EMPTY_CONFIG}"
: > "${IGNORE_FILE}"

STATUS=ok

# ── .trivyignore: base branch on PRs, checked-out file otherwise ────────────
IGNORE_SOURCE="none"
if [ "${EVENT_NAME}" = "pull_request" ]; then
  BASE="refs/remotes/origin/${BASE_REF}"
  if ! git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null; then
    echo "::warning::Base branch origin/${BASE_REF} is not in the checkout (fetch-depth 0 needed); scanning without any .trivyignore."
  elif git cat-file -e "${BASE}:.trivyignore" 2>/dev/null; then
    git show "${BASE}:.trivyignore" > "${IGNORE_FILE}"
    IGNORE_SOURCE="base branch ${BASE_REF}"
    if [ -f ".trivyignore" ] && ! cmp -s ".trivyignore" "${IGNORE_FILE}"; then
      echo "::notice::This PR changes .trivyignore; the change is ignored until merged. Scanning with the base branch .trivyignore."
    fi
  elif [ -e ".trivyignore" ]; then
    echo "::notice::This PR adds .trivyignore; it is ignored until merged."
  fi
elif [ -f ".trivyignore" ]; then
  cp -- ".trivyignore" "${IGNORE_FILE}"
  IGNORE_SOURCE="checkout"
fi
echo "Ignore file: .trivyignore from ${IGNORE_SOURCE}."

COMMON=(--config "${EMPTY_CONFIG}" --ignorefile "${IGNORE_FILE}")

SCAN_ARGS=(fs "${COMMON[@]}" --scanners vuln --cache-dir "${WORK_DIR}/cache"
           --no-progress --list-all-pkgs=false --exit-code 0
           --format json --output "${FULL}")
[ "${IGNORE_UNFIXED}" = "true" ] && SCAN_ARGS+=(--ignore-unfixed)

echo "::group::Trivy filesystem scan (vulnerabilities, all severities)"
if ! "${TRIVY_BIN}" "${SCAN_ARGS[@]}" "${SCAN_PATH}"; then
  echo "::error::Trivy could not scan '${SCAN_PATH}'."
  STATUS=error
fi
echo "::endgroup::"

if [ "${STATUS}" = ok ]; then
  if ! "${TRIVY_BIN}" convert "${COMMON[@]}" --quiet --format json --list-all-pkgs=false \
         --severity "${SEVERITY}" --output "${FILTERED}" "${FULL}"; then
    echo "::error::trivy convert (json) failed; check the severity input ('${SEVERITY}')."
    STATUS=error
  fi
fi

if [ "${STATUS}" = ok ]; then
  # Human-readable list in the log; never decides the verdict.
  "${TRIVY_BIN}" convert "${COMMON[@]}" --quiet --format table \
    --severity "${SEVERITY}" --exit-code 0 "${FULL}" || true
  if [ "${WANT_SARIF}" = "true" ]; then
    if ! "${TRIVY_BIN}" convert "${COMMON[@]}" --quiet --format sarif \
           --severity "${SEVERITY}" --output "${SARIF}" "${FULL}"; then
      echo "::warning::trivy convert (sarif) failed; no SARIF upload."
      rm -f "${SARIF}"
    fi
  fi
fi

# ── dependency-vuln-report.json (read by the CI gate report) ───────────────
# Same shape as docker-vuln-report.json: {meta, results}.
VULN_COUNT=""
if [ "${STATUS}" = ok ] && [ -s "${FILTERED}" ]; then
  VULN_COUNT=$(jq '[.Results[]?.Vulnerabilities // [] | length] | add // 0' "${FILTERED}" 2>/dev/null || true)
  [[ "${VULN_COUNT}" =~ ^[0-9]+$ ]] || { echo "::error::Could not read the Trivy JSON report."; STATUS=error; VULN_COUNT=""; }
fi
[ -s "${FILTERED}" ] || echo '{"Results":[]}' > "${FILTERED}"
if ! jq -n \
    --slurpfile raw            "${FILTERED}" \
    --arg        scan_path     "${SCAN_PATH}" \
    --arg        sha           "${SHA}" \
    --arg        severity      "${SEVERITY}" \
    --arg        status        "${STATUS}" \
    --arg        ignore_source "${IGNORE_SOURCE}" \
    --argjson    ignore_unfixed "$([ "${IGNORE_UNFIXED}" = "true" ] && echo true || echo false)" \
    '($raw[0].Results // []) as $r
     | [$r[]?.Vulnerabilities // [] | .[]] as $v
     | {
         meta: {
           scan_path:           $scan_path,
           sha:                 $sha,
           scan_status:         $status,
           severity_filter:     $severity,
           ignore_unfixed:      $ignore_unfixed,
           trivyignore:         $ignore_source,
           targets_scanned:     ($r | length),
           vulnerability_count: ($v | length),
           by_severity:         ($v | group_by(.Severity) | map({key: .[0].Severity, value: length}) | from_entries)
         },
         results: $r
       }' > "${REPORT_DIR}/dependency-vuln-report.json"; then
  echo "::error::Could not write dependency-vuln-report.json."
  STATUS=error
fi

{
  echo "status=${STATUS}"
  echo "vuln-count=${VULN_COUNT}"
  echo "report-dir=${REPORT_DIR}"
  [ "${STATUS}" = ok ] && [ -s "${SARIF}" ] && echo "sarif=${SARIF}"
} >> "${GITHUB_OUTPUT}"
# STATUS describes the scan run (ok = completed), not the verdict; the
# verdict comes from the count in the composite's result step.
if [ "${STATUS}" = ok ]; then
  echo "Dependency scan completed: ${VULN_COUNT:-unknown} vulnerabilities at ${SEVERITY}"
else
  echo "Dependency scan did not complete (${STATUS})"
fi
exit 0
