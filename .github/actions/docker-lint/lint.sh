#!/usr/bin/env bash
# Lints every target with Hadolint and Checkov. Never exits non-zero for a
# finding: outcomes are collected per target and reported at the end.
#
# Env:  WORK_DIR       from prepare.sh (targets.json, hadolint-ignore, checkov-skip)
#       HADOLINT_BIN   from install-hadolint.sh
#       CHECKOV_IMAGE  digest-pinned image reference
#       GITHUB_WORKSPACE, GITHUB_OUTPUT, GITHUB_STEP_SUMMARY (runner)
# Out:  <WORK_DIR>/sarif/hadolint/<name>.sarif, <WORK_DIR>/sarif/checkov/<name>.sarif
#         (runs[].automationDetails.id set to the per-target category)
#       <WORK_DIR>/results/[docker-lint-result-<id>/]docker-lint-result.json
#       GITHUB_OUTPUT  failed-targets, hadolint-sarif-dir, hadolint-sarif-count,
#                      checkov-sarif-dir, checkov-sarif-count, results-dir
set -uo pipefail

TARGETS_FILE="${WORK_DIR}/targets.json"
HL_SARIF_DIR="${WORK_DIR}/sarif/hadolint"
CK_SARIF_DIR="${WORK_DIR}/sarif/checkov"
RESULTS_DIR="${WORK_DIR}/results"
RAW_DIR="${WORK_DIR}/raw"
mkdir -p "${HL_SARIF_DIR}" "${CK_SARIF_DIR}" "${RESULTS_DIR}" "${RAW_DIR}"

COUNT=$(jq 'length' "${TARGETS_FILE}")

# Hadolint options go through the same environment variables hadolint-action
# v3.1.0 set (not CLI flags), so their precedence over a repository's
# .hadolint.yaml is exactly as in v1.
export HADOLINT_FORMAT=sarif
export HADOLINT_FAILURE_THRESHOLD=info
export HADOLINT_NOFAIL=false
export HADOLINT_VERBOSE=false
export NO_COLOR=false
HADOLINT_IGNORE=$(paste -sd, "${WORK_DIR}/hadolint-ignore")
if [ -n "${HADOLINT_IGNORE}" ]; then export HADOLINT_IGNORE; else unset HADOLINT_IGNORE; fi
unset HADOLINT_TRUSTED_REGISTRIES

CK_ARGS=(--framework dockerfile)
while IFS= read -r check; do
  [ -n "${check}" ] && CK_ARGS+=(--skip-check "${check}")
done < "${WORK_DIR}/checkov-skip"
CK_ARGS+=(--output cli --output sarif --output-file-path "console,/checkov-out/")

# set_category <in.sarif> <out.sarif> <category>
# Copies a SARIF file, giving every run the category upload-sarif would have
# derived from its `category` input (it appends a trailing slash).
set_category() {
  jq --arg id "$3/" '.runs |= map(.automationDetails = {id: $id})' "$1" > "$2" 2>/dev/null \
    || { rm -f "$2"; echo "::warning::$1 is not valid SARIF; not uploaded."; }
}

FAILED='[]'
SUMMARY_ROWS=""

for ((i = 0; i < COUNT; i++)); do
  DOCKERFILE=$(jq -r ".[${i}].dockerfile" "${TARGETS_FILE}")
  TID=$(jq -r ".[${i}].tid" "${TARGETS_FILE}")
  SUFFIX="${TID:+-${TID}}"
  NAME="${TID:-dockerfile}"
  echo "::group::${DOCKERFILE} (target-id: ${TID:-<none>})"

  HL_RAW="${RAW_DIR}/hadolint-${NAME}.sarif"
  CK_OUT="${RAW_DIR}/checkov-${NAME}"
  mkdir -p "${CK_OUT}"
  HADOLINT_OUTCOME=failure
  CHECKOV_OUTCOME=failure

  if [ ! -f "${DOCKERFILE}" ]; then
    echo "::error file=${DOCKERFILE}::Dockerfile not found: ${DOCKERFILE}"
  else
    # ── Multi-stage build advisory (never fails) ────────────────────────────
    FROM_COUNT=$(grep -ciE '^FROM[[:space:]]' "${DOCKERFILE}" || true)
    echo "FROM instructions found: ${FROM_COUNT}"
    if [ "${FROM_COUNT}" -lt 2 ]; then
      echo "::warning file=${DOCKERFILE}::Single-stage build detected. Consider multi-stage builds to minimise final image size and remove build-time tooling from the runtime image."
    else
      echo "Multi-stage build confirmed (${FROM_COUNT} FROM instructions)."
    fi

    # ── Hadolint ────────────────────────────────────────────────────────────
    echo "Hadolint: hadolint ${DOCKERFILE} (format sarif, failure-threshold info, ignore ${HADOLINT_IGNORE:-<none>})"
    if "${HADOLINT_BIN}" "${DOCKERFILE}" > "${HL_RAW}"; then
      HADOLINT_OUTCOME=success
    fi
    jq -r '.runs[0].results[]? | "  \(.ruleId) [\(.level // "warning")] line \(.locations[0].physicalLocation.region.startLine // 0): \(.message.text // "")"' "${HL_RAW}" 2>/dev/null || true
    echo "Hadolint: ${HADOLINT_OUTCOME}"

    # ── Checkov ─────────────────────────────────────────────────────────────
    # Same layout as the Docker action: workspace at /github/workspace as the
    # working directory, so SARIF paths match v1. Runs as root, like the action.
    echo "Checkov: checkov -f ${DOCKERFILE} ${CK_ARGS[*]}"
    if docker run --rm \
         -v "${GITHUB_WORKSPACE}:/github/workspace" -w /github/workspace \
         -v "${CK_OUT}:/checkov-out" \
         -e LOG_LEVEL=WARNING -e BC_SOURCE=githubActions \
         --entrypoint checkov \
         "${CHECKOV_IMAGE}" -f "${DOCKERFILE}" "${CK_ARGS[@]}"; then
      CHECKOV_OUTCOME=success
    fi
    echo "Checkov: ${CHECKOV_OUTCOME}"
  fi

  # ── SARIF with per-target category ───────────────────────────────────────
  [ -s "${HL_RAW}" ] && set_category "${HL_RAW}" "${HL_SARIF_DIR}/${NAME}.sarif" "hadolint-dockerfile${SUFFIX}"
  [ -s "${CK_OUT}/results_sarif.sarif" ] && set_category "${CK_OUT}/results_sarif.sarif" "${CK_SARIF_DIR}/${NAME}.sarif" "checkov-dockerfile${SUFFIX}"

  # ── Result JSON (v1 schema, read by the CI report) ───────────────────────
  HL='[]'; CK='[]'
  if [ -s "${HL_RAW}" ]; then
    HL=$(jq -c '[ .runs[0].results[]? | {id: .ruleId, level: (.level // "warning"), line: (.locations[0].physicalLocation.region.startLine // 0), msg: (.message.text // "")} ]' "${HL_RAW}" 2>/dev/null || echo '[]')
  fi
  if [ -s "${CK_OUT}/results_sarif.sarif" ]; then
    CK=$(jq -c '[ .runs[0].results[]? | {id: .ruleId, line: (.locations[0].physicalLocation.region.startLine // 0), msg: (.message.text // "")} ]' "${CK_OUT}/results_sarif.sarif" 2>/dev/null || echo '[]')
  fi
  if [ "${COUNT}" -eq 1 ]; then
    RESULT_FILE="${RESULTS_DIR}/docker-lint-result.json"
  else
    mkdir -p "${RESULTS_DIR}/docker-lint-result${SUFFIX}"
    RESULT_FILE="${RESULTS_DIR}/docker-lint-result${SUFFIX}/docker-lint-result.json"
  fi
  jq -nc \
    --arg tid "${TID}" --arg df "${DOCKERFILE}" \
    --arg ho "${HADOLINT_OUTCOME}" --arg co "${CHECKOV_OUTCOME}" \
    --argjson hl "${HL}" --argjson ck "${CK}" \
    '{target_id:$tid, dockerfile:$df, hadolint_outcome:$ho, checkov_outcome:$co, hadolint_findings:$hl, checkov_failed:$ck}' \
    > "${RESULT_FILE}"
  echo "Lint result for ${DOCKERFILE}:"; cat "${RESULT_FILE}"

  if [ "${HADOLINT_OUTCOME}" != success ] || [ "${CHECKOV_OUTCOME}" != success ]; then
    FAILED=$(jq -c --arg t "${TID:-${DOCKERFILE}}" '. + [$t]' <<< "${FAILED}")
    TOOLS=""
    [ "${HADOLINT_OUTCOME}" != success ] && TOOLS="${TOOLS} Hadolint"
    [ "${CHECKOV_OUTCOME}" != success ] && TOOLS="${TOOLS} Checkov"
    echo "::error file=${DOCKERFILE}::Dockerfile lint/security check(s) failed:${TOOLS}"
  fi
  SUMMARY_ROWS+="| \`${DOCKERFILE}\` | ${TID:-} | ${HADOLINT_OUTCOME} | ${CHECKOV_OUTCOME} |"$'\n'
  echo "::endgroup::"
done

{
  echo "### Dockerfile lint"
  echo ""
  echo "| Dockerfile | Target id | Hadolint | Checkov |"
  echo "|---|---|---|---|"
  printf '%s' "${SUMMARY_ROWS}"
} >> "${GITHUB_STEP_SUMMARY}"

HL_COUNT=$(find "${HL_SARIF_DIR}" -name '*.sarif' -type f | wc -l | tr -d ' ')
CK_COUNT=$(find "${CK_SARIF_DIR}" -name '*.sarif' -type f | wc -l | tr -d ' ')
{
  echo "failed-targets=${FAILED}"
  echo "hadolint-sarif-dir=${HL_SARIF_DIR}"
  echo "hadolint-sarif-count=${HL_COUNT}"
  echo "checkov-sarif-dir=${CK_SARIF_DIR}"
  echo "checkov-sarif-count=${CK_COUNT}"
  echo "results-dir=${RESULTS_DIR}"
} >> "${GITHUB_OUTPUT}"
echo "Linted ${COUNT} Dockerfile(s); failed: ${FAILED}"
exit 0
