#!/usr/bin/env bash
# Sends a test notification from the running server to every configured adapter.
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
compose_setup
[[ -n "$(docker compose ps -q --status running valheim)" ]] \
  || die "The server isn't running, or is asleep. Start it with ./restart.sh, then try again."
docker compose exec -T valheim /opt/notify/notify.sh test
