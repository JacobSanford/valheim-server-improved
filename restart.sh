#!/usr/bin/env bash
# Pulls the latest image and (re)starts the server, then follows the logs.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_env_file

# The server refuses to start with a bad password; catch it here instead of in the log.
if [[ -z "$(env_value SERVER_PASS_FILE)" ]]; then
  pass="$(env_value SERVER_PASS)"
  name="$(env_value SERVER_NAME)"
  [[ "${pass}" != "changeme" ]] || die "SERVER_PASS in ${ENV_FILE} is still the example value. Set your own."
  (( ${#pass} >= 5 )) || die "SERVER_PASS in ${ENV_FILE} must be at least 5 characters."
  [[ "${name}" != *"${pass}"* ]] || die "SERVER_PASS must not appear in SERVER_NAME."
fi

check_backup_settings
compose_setup

docker compose pull
docker compose up -d --force-recreate --remove-orphans
docker compose logs -f --tail 200
