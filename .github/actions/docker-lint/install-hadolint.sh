#!/usr/bin/env bash
# Installs the Hadolint v2.12.0 release binary into <WORK_DIR>/bin after
# checking it against a pinned SHA-256.
#
# Hashes: from hadolint-Linux-<arch>.sha256 on the v2.12.0 release, checked
# against the downloaded binaries. v2.12.0 is the version hadolint-action
# v3.1.0 runs (its image is ghcr.io/hadolint/hadolint:v2.12.0-debian).
# Bump version and both hashes together.
#
# Env:  WORK_DIR  from prepare.sh
# Out:  GITHUB_OUTPUT  path=<absolute path of the hadolint binary>
set -euo pipefail

VERSION="v2.12.0"
case "${RUNNER_ARCH:-X64}" in
  X64)   ASSET="hadolint-Linux-x86_64"; SHA256="56de6d5e5ec427e17b74fa48d51271c7fc0d61244bf5c90e828aab8362d55010" ;;
  ARM64) ASSET="hadolint-Linux-arm64";  SHA256="5798551bf19f33951881f15eb238f90aef023f11e7ec7e9f4c37961cb87c5df6" ;;
  *) echo "::error::No pinned Hadolint binary for runner architecture '${RUNNER_ARCH}'."; exit 1 ;;
esac
if [ "${RUNNER_OS:-Linux}" != "Linux" ]; then
  echo "::error::Dockerfile lint needs a Linux runner (got ${RUNNER_OS})."
  exit 1
fi

BIN_DIR="${WORK_DIR}/bin"
mkdir -p "${BIN_DIR}"
curl -fsSL --retry 3 --retry-all-errors -o "${BIN_DIR}/hadolint" \
  "https://github.com/hadolint/hadolint/releases/download/${VERSION}/${ASSET}"
if ! echo "${SHA256}  ${BIN_DIR}/hadolint" | sha256sum --check --strict --quiet -; then
  echo "::error::SHA-256 mismatch for ${ASSET} ${VERSION}; refusing to run it."
  rm -f "${BIN_DIR}/hadolint"
  exit 1
fi
chmod 0755 "${BIN_DIR}/hadolint"
"${BIN_DIR}/hadolint" --version
echo "path=${BIN_DIR}/hadolint" >> "${GITHUB_OUTPUT}"
