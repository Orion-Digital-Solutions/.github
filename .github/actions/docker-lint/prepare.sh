#!/usr/bin/env bash
# Validates the `targets` input and normalises the tool option lists.
#
# Env:  TARGETS                 JSON array of {dockerfile, context, target-id}
#       RAW_IGNORE              Hadolint rule IDs, comma/space/newline separated
#       RAW_SKIP                Checkov check IDs, comma separated
#       HADOLINT_VERSION_INPUT  v1 compatibility input (warned, not used)
# Out:  GITHUB_OUTPUT  work-dir, count
#       <work-dir>/targets.json        [{dockerfile, tid}]
#       <work-dir>/hadolint-ignore     one rule ID per line
#       <work-dir>/checkov-skip        one check ID per line
set -euo pipefail

if ! printf '%s' "${TARGETS}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
  echo "::error::'targets' must be a non-empty JSON array of {\"dockerfile\", \"context\", \"target-id\"} objects."
  exit 1
fi
if ! printf '%s' "${TARGETS}" | jq -e 'all(.[]; type == "object" and ((.dockerfile // "") | type == "string" and length > 0))' >/dev/null; then
  echo "::error::Every element of 'targets' must be an object with a non-empty \"dockerfile\" string."
  exit 1
fi

# Paths are echoed into workflow commands (::warning file=...::); refuse
# control characters so a crafted file name cannot inject one.
if printf '%s' "${TARGETS}" | jq -e 'any(.[]; .dockerfile | explode | any(. < 32 or . == 127))' >/dev/null; then
  echo "::error::A \"dockerfile\" path in 'targets' contains control characters."
  exit 1
fi

COUNT=$(printf '%s' "${TARGETS}" | jq 'length')
NORMALISED=$(printf '%s' "${TARGETS}" | jq -c '[ .[] | {dockerfile: .dockerfile, tid: ((."target-id" // "") | tostring)} ]')

# target-id ends up in SARIF categories, artifact paths and file names.
BAD_IDS=$(printf '%s' "${NORMALISED}" | jq -r '.[] | select(.tid != "" and (.tid | test("^[A-Za-z0-9_][A-Za-z0-9._-]*$") | not)) | .tid')
if [ -n "${BAD_IDS}" ]; then
  echo "::error::Invalid target-id(s) (allowed: letters, digits, '.', '_', '-'; not starting with '.' or '-'): ${BAD_IDS//$'\n'/, }"
  exit 1
fi
if [ "${COUNT}" -gt 1 ]; then
  if printf '%s' "${NORMALISED}" | jq -e 'any(.[]; .tid == "")' >/dev/null; then
    echo "::error::With more than one target, every target needs a non-empty \"target-id\"."
    exit 1
  fi
  DUPES=$(printf '%s' "${NORMALISED}" | jq -r '[.[].tid] | group_by(.) | map(select(length > 1) | .[0]) | join(", ")')
  if [ -n "${DUPES}" ]; then
    echo "::error::Duplicate target-id(s): ${DUPES}"
    exit 1
  fi
fi

case "${HADOLINT_VERSION_INPUT}" in
  v2.12.0|2.12.0|"") ;;
  *) echo "::warning::hadolint-version '${HADOLINT_VERSION_INPUT}' is ignored: Hadolint is pinned to v2.12.0 (as hadolint-action v3.1.0 was in v1)." ;;
esac

WORK_DIR=$(mktemp -d "${RUNNER_TEMP:-/tmp}/docker-lint.XXXXXX")
printf '%s\n' "${NORMALISED}" > "${WORK_DIR}/targets.json"

# Hadolint: split on commas and whitespace (v1 documented spaces, the action
# wanted commas; ROADMAP 2.6). Checkov: split on commas and trim, like
# checkov-action's entrypoint (add_csv).
printf '%s' "${RAW_IGNORE}" | tr ', \t\r\n' '\n' | sed '/^$/d' > "${WORK_DIR}/hadolint-ignore"
printf '%s' "${RAW_SKIP}" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' > "${WORK_DIR}/checkov-skip"

echo "Targets (${COUNT}):"
jq -r '.[] | "  - \(.dockerfile)  (id: \(if .tid == "" then "<none>" else .tid end))"' "${WORK_DIR}/targets.json"
echo "Hadolint ignore: $(paste -sd, "${WORK_DIR}/hadolint-ignore" || true)"
echo "Checkov skip:    $(paste -sd, "${WORK_DIR}/checkov-skip" || true)"

{
  echo "work-dir=${WORK_DIR}"
  echo "count=${COUNT}"
} >> "${GITHUB_OUTPUT}"
