#!/usr/bin/env bash
# Stops the server and removes the container. World data is kept.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
compose_setup
docker compose down --remove-orphans
