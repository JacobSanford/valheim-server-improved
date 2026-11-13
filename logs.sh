#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
compose_setup
docker compose logs -f --tail 200
