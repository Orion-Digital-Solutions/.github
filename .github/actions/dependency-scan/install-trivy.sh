#!/usr/bin/env bash
# Installs the Trivy v0.70.0 release binary into <WORK_DIR>/bin after checking
# the tarball against a pinned SHA-256.
#
# v0.70.0 is the version aquasecurity/trivy-action v0.36.0 (our v1 pin)
# installs by default. Installing it directly, instead of through the action,
# gives one binary for one scan plus `trivy convert`, with the hash fixed in
# this repository rather than taken from the release's own checksums file at
# run time (setup-trivy's install path).
#
# Hashes: from trivy_0.70.0_checksums.txt on the v0.70.0 release, matching the
# release API's asset digests and the downloaded tarballs. Bump version and
# both hashes together.
#
# COPY of .github/actions/docker-image/install-trivy.sh (each composite ships
# its own scripts). Keep the two files identical when bumping Trivy.
#
# Env:  WORK_DIR
# Out:  GITHUB_OUTPUT  path=<absolute path of the trivy binary>
set -euo pipefail

VERSION="0.70.0"
case "${RUNNER_ARCH:-X64}" in
  X64)   ASSET="trivy_${VERSION}_Linux-64bit.tar.gz"; SHA256="8b4376d5d6befe5c24d503f10ff136d9e0c49f9127a4279fd110b727929a5aa9" ;;
  ARM64) ASSET="trivy_${VERSION}_Linux-ARM64.tar.gz"; SHA256="2f6bb988b553a1bbac6bdd1ce890f5e412439564e17522b88a4541b4f364fc8d" ;;
  *) echo "::error::No pinned Trivy binary for runner architecture '${RUNNER_ARCH}'."; exit 1 ;;
esac

BIN_DIR="${WORK_DIR}/bin"
mkdir -p "${BIN_DIR}"
curl -fsSL --retry 3 --retry-all-errors -o "${WORK_DIR}/${ASSET}" \
  "https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/${ASSET}"
if ! echo "${SHA256}  ${WORK_DIR}/${ASSET}" | sha256sum --check --strict --quiet -; then
  echo "::error::SHA-256 mismatch for ${ASSET}; refusing to install it."
  rm -f "${WORK_DIR}/${ASSET}"
  exit 1
fi
tar -xzf "${WORK_DIR}/${ASSET}" -C "${BIN_DIR}" trivy
rm -f "${WORK_DIR}/${ASSET}"
"${BIN_DIR}/trivy" --version
echo "path=${BIN_DIR}/trivy" >> "${GITHUB_OUTPUT}"
