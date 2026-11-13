#!/usr/bin/env bash
# Runs tests/in-image.sh inside the Valheim image, so the hooks and notifier are
# checked against the image's own bash, mawk, curl, python3 and log filter.
# Needs Docker and pulls the image if it isn't present. Starts no server.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${VALHEIM_IMAGE:-ghcr.io/community-valheim-tools/valheim-server}"

if ! docker info >/dev/null 2>&1; then
  echo "image.test.sh: skipped, Docker is not available"
  exit 0
fi

docker image inspect "${IMAGE}" >/dev/null 2>&1 || docker pull -q "${IMAGE}" >/dev/null || exit 1

# The hooks run as PUID in the real container, so run as a non-root user here too.
exec docker run --rm --network none --user 1000:1000 \
  --entrypoint /bin/bash \
  -v "${REPO}:/repo:ro" \
  -v "${REPO}/notify:/opt/notify:ro" \
  -v "${REPO}/hooks:/opt/hooks:ro" \
  "${IMAGE}" /repo/tests/in-image.sh
