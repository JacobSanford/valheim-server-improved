#!/usr/bin/env bash
# Deletes the world saves and backups, then starts a new world.
# The admin, ban and permitted player lists in data/ are kept.
# A full tarball of ./data and ./backups is saved to ./wipe-archives first.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_env_file
compose_setup
WORLD_NAME="$(env_value WORLD_NAME)"
[[ -n "${WORLD_NAME}" ]] || die "WORLD_NAME is not set in ${ENV_FILE}."

# Everything the wipe deletes. worlds/ holds pre-1.0 saves, if any.
WIPE_DIRS=()
for d in data/worlds_local data/worlds; do
  [[ -e "${d}" ]] && WIPE_DIRS+=("${d}")
done

# Fail now, before anything is touched, rather than half way through the delete.
for d in data backups; do
  [[ -w "${d}" ]] || die "${d}/ is not writable by $(id -un). Fix its ownership, then rerun."
done
if [[ ${#WIPE_DIRS[@]} -gt 0 ]]; then
  unwritable="$(find "${WIPE_DIRS[@]}" backups -type d ! -writable -print -quit)"
else
  unwritable="$(find backups -type d ! -writable -print -quit)"
fi
[[ -z "${unwritable}" ]] || die "${unwritable} is not writable by $(id -un). Fix its ownership, then rerun."

echo "This will PERMANENTLY wipe world '${WORLD_NAME}' and its backups."
echo "The admin, ban and permitted player lists are kept."
read -r -p "Type the world name to confirm: " CONFIRM
[[ "${CONFIRM}" == "${WORLD_NAME}" ]] || die "Confirmation did not match. Aborting."

docker compose down --remove-orphans
mkdir -p wipe-archives
ARCHIVE="wipe-archives/${WORLD_NAME}-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "${ARCHIVE}" data backups
echo "Archived current data to ${ARCHIVE}"

if [[ ${#WIPE_DIRS[@]} -gt 0 ]]; then
  rm -rf -- "${WIPE_DIRS[@]}"
fi
find backups -mindepth 1 -delete

exec ./restart.sh
