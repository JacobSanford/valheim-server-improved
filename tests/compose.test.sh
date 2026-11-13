#!/usr/bin/env bash
# docker-compose.yml with and without docker-compose.sleep.yml, rendered with
# `docker compose config`. Nothing is started.
source "$(dirname "$0")/helpers.sh"

if ! docker compose version >/dev/null 2>&1; then
  echo "compose.test.sh: skipped, docker compose is not available"
  exit 0
fi

# A copy with the example env file, so the real env/valheim.env is never read.
DIR="${TMP_ROOT}/checkout"
mkdir -p "${DIR}/env"
cp "${REPO}/docker-compose.yml" "${REPO}/docker-compose.sleep.yml" "${DIR}/"
cp "${REPO}/env/valheim.env.example" "${DIR}/env/valheim.env"

# render [COMPOSE_FILE]: prints the config as JSON.
render() {
  (cd "${DIR}" && COMPOSE_FILE="${1:-docker-compose.yml}" docker compose config --format json)
}

# q JSON EXPR: evaluate a Python expression on the parsed config (`c`).
q() { python3 -c "import json,sys; c=json.load(sys.stdin)['services']; print($2)" <<< "$1"; }

ports='sorted(p.get("host_ip", "") + ":" + str(p["published"]) + "->" + str(p["target"]) + "/" + p["protocol"] for p in c[S].get("ports", []))'

section "sleep off (base file only)"
OFF="$(render)"
assert_eq "$(q "${OFF}" 'sorted(c)')" "['valheim']" "only the valheim service"
assert_eq "$(q "${OFF}" "${ports//S/\"valheim\"}")" \
  "['127.0.0.1:8456->80/tcp', ':2456->2456/udp', ':2457->2457/udp']" \
  "valheim publishes the game ports, and the status page on localhost only"
assert_eq "$(q "${OFF}" 'sorted(v["target"] for v in c["valheim"]["volumes"])')" \
  "['/config', '/config/backups', '/opt/hooks', '/opt/notify', '/opt/valheim']" "all five mounts"
assert_eq "$(q "${OFF}" 'sorted(v["target"] for v in c["valheim"]["volumes"] if v.get("read_only"))')" \
  "['/opt/hooks', '/opt/notify']" "notify and hooks are read-only"
assert_eq "$(q "${OFF}" '"healthcheck" in c["valheim"]')" "True" "healthcheck present"
assert_eq "$(q "${OFF}" 'c["valheim"]["logging"]["options"]')" "{'max-file': '3', 'max-size': '10m'}" "logs capped"
assert_eq "$(q "${OFF}" 'c["valheim"].get("tty", False) or c["valheim"].get("stdin_open", False)')" "False" "no tty or stdin"

section "sleep on (base + sleep file)"
ON="$(SLEEP_METHOD=pause SLEEP_AFTER_SECONDS=900 SLEEP_MIN_PACKETS=7 render docker-compose.yml:docker-compose.sleep.yml)"
assert_eq "$(q "${ON}" 'sorted(c)')" "['lazytainer', 'valheim']" "adds the lazytainer service"
assert_eq "$(q "${ON}" "${ports//S/\"valheim\"}")" "[]" "valheim publishes no ports itself"
assert_eq "$(q "${ON}" 'c["valheim"]["network_mode"]')" "service:lazytainer" "valheim shares lazytainer's network"
assert_eq "$(q "${ON}" "${ports//S/\"lazytainer\"}")" \
  "['127.0.0.1:8456->80/tcp', ':2456->2456/udp', ':2457->2457/udp']" "lazytainer publishes the same ports"
assert_eq "$(q "${ON}" 'c["valheim"]["labels"]')" "{'lazytainer.group': 'valheim'}" "valheim is in the lazytainer group"
assert_eq "$(q "${ON}" 'c["lazytainer"]["image"]')" "ghcr.io/vmorganp/lazytainer:2.0.31" "lazytainer image is pinned"
assert_eq "$(q "${ON}" 'sorted((k.split(".")[-1], v) for k, v in c["lazytainer"]["labels"].items())')" \
  "[('inactiveTimeout', '900'), ('minPacketThreshold', '7'), ('pollRate', '5'), ('ports', '2456,2457'), ('sleepMethod', 'pause')]" \
  "sleep settings reach the lazytainer labels"
assert_eq "$(q "${ON}" '"healthcheck" in c["valheim"]')" "True" "healthcheck kept"

DEFAULTS="$(render docker-compose.yml:docker-compose.sleep.yml)"
assert_eq "$(q "${DEFAULTS}" 'sorted((k.split(".")[-1], v) for k, v in c["lazytainer"]["labels"].items() if "Timeout" in k or "Threshold" in k or "Method" in k)')" \
  "[('inactiveTimeout', '1200'), ('minPacketThreshold', '10'), ('sleepMethod', 'stop')]" "defaults without lib.sh: stop, 1200 s, 10 packets"

section "env example"
for line in "SLEEP_WHEN_IDLE=false" "NOTIFY_EVENTS=" "BACKUPS_MAX_AGE=36500" "BACKUPS_KEEP_DAYS=30" "BACKUPS_KEEP_MIN=3" "PUID=1000" \
            "POST_BACKUP_HOOK=/opt/hooks/idle-backups.sh prune @BACKUP_FILE@ && /opt/notify/notify.sh backup @BACKUP_FILE@ || true"; do
  assert_contains "$(cat "${REPO}/env/valheim.env.example")" "${line}" "env example has ${line%%=*}"
done

finish
