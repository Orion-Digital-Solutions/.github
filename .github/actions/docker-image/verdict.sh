#!/usr/bin/env bash
# Collects the outcome of every check and fails once.
#
# Env:  step outcomes PREPARE BUILDX BUILD LABELS TRIVY_INSTALL GRYPE SBOM_SPDX
#       SBOM_CDX DIVE (success | failure | skipped | ""), READY (true|false),
#       TRIVY_RESULT (pass | fail | error | ""), SEVERITY, FAIL_ON_FINDINGS
# Out:  GITHUB_OUTPUT  result=clean|findings|error, failed-checks=<JSON array>
set -uo pipefail

ERRORS=()
FINDINGS=()

if [ "${PREPARE}" != success ];   then ERRORS+=(prepare)
elif [ "${BUILDX}" != success ];  then ERRORS+=(buildx)
elif [ "${BUILD}" != success ];   then ERRORS+=(build)
fi
[ "${LABELS}" = failure ] && FINDINGS+=(labels)

if [ "${READY}" = true ]; then
  [ "${TRIVY_INSTALL}" = failure ] && ERRORS+=(trivy-install)
  if [ "${TRIVY_INSTALL}" = success ]; then
    case "${TRIVY_RESULT}" in
      pass) ;;
      fail) FINDINGS+=(trivy) ;;
      *)    ERRORS+=(trivy) ;;
    esac
  fi
  if [ "${GRYPE}" = failure ]; then
    FINDINGS+=(grype)
    echo "::error::Grype: vulnerabilities at or above its cutoff (lowest level in '${SEVERITY}'). See the Grype step log or the GitHub Security tab."
  fi
  [ "${SBOM_SPDX}" = failure ] && ERRORS+=(sbom-spdx)
  [ "${SBOM_CDX}" = failure ] && ERRORS+=(sbom-cyclonedx)
  [ "${DIVE}" = failure ] && FINDINGS+=(dive)
fi

RESULT=clean
[ "${#FINDINGS[@]}" -gt 0 ] && RESULT=findings
[ "${#ERRORS[@]}" -gt 0 ] && RESULT=error
FAILED=$(printf '%s\n' "${ERRORS[@]}" "${FINDINGS[@]}" | sed '/^$/d' | jq -Rsc 'split("\n") | map(select(length > 0))')

{
  echo "result=${RESULT}"
  echo "failed-checks=${FAILED}"
} >> "${GITHUB_OUTPUT}"
echo "Image checks: ${RESULT}; failed: ${FAILED}"

if [ "${RESULT}" != clean ] && [ "${FAIL_ON_FINDINGS}" = "true" ]; then
  echo "::error::Docker image check(s) failed: $(printf '%s' "${FAILED}" | jq -r 'join(", ")'). See the step logs above."
  exit 1
fi
exit 0
