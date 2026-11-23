#!/usr/bin/env bash
# Validates the inputs and computes the build metadata.
#
# Env:  DOCKERFILE, CONTEXT, IMAGE_NAME, TARGET_ID, REPO_URL, SHA, REF_NAME
# Out:  GITHUB_OUTPUT  work-dir, suffix, cache-scope, labels (multi-line)
set -euo pipefail

if [ -n "${TARGET_ID}" ] && ! [[ "${TARGET_ID}" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; then
  echo "::error::Invalid target-id '${TARGET_ID}' (allowed: letters, digits, '.', '_', '-'; not starting with '.' or '-')."
  exit 1
fi
if [ -z "${IMAGE_NAME}" ]; then
  echo "::error::image-name is empty."
  exit 1
fi
if [ ! -f "${DOCKERFILE}" ]; then
  echo "::error::Dockerfile not found: ${DOCKERFILE}"
  exit 1
fi
if [ ! -d "${CONTEXT}" ]; then
  echo "::error::Build context is not a directory: ${CONTEXT}"
  exit 1
fi

WORK_DIR=$(mktemp -d "${RUNNER_TEMP:-/tmp}/docker-image.XXXXXX")
SUFFIX="${TARGET_ID:+-${TARGET_ID}}"
DELIM="LABELS_$(openssl rand -hex 8)"

# The four core OCI labels are always injected; labels declared in the
# Dockerfile are kept, these only add or override.
{
  echo "work-dir=${WORK_DIR}"
  echo "suffix=${SUFFIX}"
  echo "cache-scope=docker-image${SUFFIX}"
  echo "labels<<${DELIM}"
  echo "org.opencontainers.image.source=${REPO_URL}"
  echo "org.opencontainers.image.revision=${SHA}"
  echo "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "org.opencontainers.image.ref.name=${REF_NAME}"
  echo "${DELIM}"
} >> "${GITHUB_OUTPUT}"
echo "Building ${IMAGE_NAME} from ${DOCKERFILE} (context ${CONTEXT}, target-id ${TARGET_ID:-<none>})"
