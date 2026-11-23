#!/usr/bin/env bash
# Dive image-efficiency check in CI mode. Only lowestEfficiency is enforced;
# the wasted-bytes rules are disabled so one large but necessary layer does
# not fail the check. Writes the Dive output to the step summary.
#
# The Dive image is pinned by digest (tag kept for readability); bump both
# together. Dive v0.13.1 is the latest release as of 2026-11-23.
#
# Env:  WORK_DIR, IMAGE_NAME, MIN_EFFICIENCY
# Exit: Dive's status (non-zero when efficiency < MIN_EFFICIENCY)
set -uo pipefail

DIVE_IMAGE="wagoodman/dive:v0.13.1@sha256:f1886e6c32c094fc41a623c1989f5cb3e48aa766da5f0be233f911fc1d85ce10"
CONFIG="${WORK_DIR}/dive-ci.yaml"
OUTPUT="${WORK_DIR}/dive-output.txt"

if ! [[ "${MIN_EFFICIENCY}" =~ ^[0-9]*\.?[0-9]+$ ]]; then
  echo "::error::dive-min-efficiency must be a number between 0 and 1 (got '${MIN_EFFICIENCY}')."
  exit 2
fi

cat > "${CONFIG}" << EOF
rules:
  lowestEfficiency: ${MIN_EFFICIENCY}
  highestWastedBytes: "disabled"
  highestUserWastedPercent: "disabled"
EOF

docker run --rm \
  -e CI=true \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${CONFIG}:/.dive-ci.yaml:ro" \
  "${DIVE_IMAGE}" \
  --ci-config /.dive-ci.yaml \
  "${IMAGE_NAME}" 2>&1 | tee "${OUTPUT}"
rc=${PIPESTATUS[0]}

{
  echo "### Image Efficiency (Dive)"
  echo ""
  echo "**Image:** \`${IMAGE_NAME}\` · **Minimum efficiency threshold:** \`${MIN_EFFICIENCY}\`"
  echo ""
  echo '```'
  cat "${OUTPUT}" 2>/dev/null || true
  echo '```'
} >> "${GITHUB_STEP_SUMMARY}"

if [ "${rc}" -ne 0 ]; then
  echo "::error::Docker image efficiency is below the minimum threshold of ${MIN_EFFICIENCY} (or Dive failed to run; see the log)."
  echo "Common causes:"
  echo "  • Downloading and then deleting files in separate RUN layers"
  echo "  • Installing dev dependencies that are not cleaned up (apt-get, pip, npm)"
  echo "  • Copying entire directories when only a subset is needed"
  echo "Review the Dive output in the job log or lower dive-min-efficiency if intentional."
fi
exit "${rc}"
