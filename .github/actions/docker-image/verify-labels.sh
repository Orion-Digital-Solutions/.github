#!/usr/bin/env bash
# Fails when any label in REQUIRED_LABELS is missing or empty on the image.
#
# Env:  IMAGE_NAME, REQUIRED_LABELS (comma-separated keys)
set -euo pipefail

echo "Inspecting labels on ${IMAGE_NAME}..."
IMAGE_LABELS=$(docker inspect --format '{{json .Config.Labels}}' "${IMAGE_NAME}")
echo "Labels found: ${IMAGE_LABELS}"

MISSING=()
IFS=',' read -ra LABELS <<< "${REQUIRED_LABELS}"
for label in "${LABELS[@]}"; do
  label=$(echo "${label}" | xargs)   # trim surrounding whitespace
  [ -z "${label}" ] && continue
  value=$(printf '%s' "${IMAGE_LABELS}" | jq -r --arg k "${label}" '(. // {})[$k] // empty')
  if [ -z "${value}" ]; then
    MISSING+=("${label}")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "::error::Missing required OCI labels: ${MISSING[*]}"
  echo "Add these to your Dockerfile with LABEL instructions, or pass them via"
  echo "build-args in the workflow caller. The build step already injects the four"
  echo "core OCI labels automatically — verify your Dockerfile does not override them."
  exit 1
fi
echo "All required OCI labels verified."
