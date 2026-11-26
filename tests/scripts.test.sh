#!/usr/bin/env bash
# The top-level scripts, run against a fake `docker` that only records its
# arguments and the sleep settings it was given. Nothing touches a real server.
source "$(dirname "$0")/helpers.sh"

FAKE_BIN="${TMP_ROOT}/bin"
mkdir -p "${FAKE_BIN}"
cat > "${FAKE_BIN}/docker" <<'EOF'
#!/bin/sh
echo "docker $* [COMPOSE_FILE=${COMPOSE_FILE:-} M=${SLEEP_METHOD:-} T=${SLEEP_AFTER_SECONDS:-} P=${SLEEP_MIN_PACKETS:-}]" >> "${DOCKER_LOG}"
case "$*" in
  *"ps -q --status running"*) [ -n "${FAKE_ASLEEP:-}" ] || echo abc123 ;;
esac
exit 0
EOF
chmod +x "${FAKE_BIN}/docker"
export PATH="${FAKE_BIN}:${PATH}"

SLEEP_FILES="docker-compose.yml:docker-compose.sleep.yml"

# checkout NAME ENV_LINE...: a copy of the scripts with this env file.
# Sets DIR and DOCKER_LOG.
checkout() {
  DIR="${TMP_ROOT}/$1"
  shift
  mkdir -p "${DIR}/env"
  cp "${REPO}"/{lib.sh,restart.sh,stop.sh,logs.sh,notify-test.sh,wipe-restart.sh} "${DIR}/"
  printf '%s\n' "$@" > "${DIR}/env/valheim.env"
  export DOCKER_LOG="${DIR}/docker.log"
  : > "${DOCKER_LOG}"
}

# run SCRIPT [STDIN]: run a script in DIR. Sets OUT (stdout+stderr), RC, CALLS.
run() {
  OUT="$(printf '%s' "${2:-}" | bash "${DIR}/$1" 2>&1)"
  RC=$?
  CALLS="$(cat "${DOCKER_LOG}")"
  : > "${DOCKER_LOG}"
}

OK=("SERVER_NAME=My Server" "SERVER_PASS=goodpass")

section "restart.sh password checks"
checkout missing-env "${OK[@]}"
rm -- "${DIR}/env/valheim.env"
run restart.sh
assert_eq "${RC}" 1 "missing env file: exits 1"
assert_contains "${OUT}" "env/valheim.env not found" "missing env file: says so"
assert_eq "${CALLS}" "" "missing env file: no docker calls"

checkout example-pass "SERVER_NAME=x" "SERVER_PASS=changeme"
run restart.sh
assert_contains "${OUT}" "still the example value" "example password refused"
assert_eq "${CALLS}" "" "example password: no docker calls"

checkout short-pass "SERVER_NAME=x" "SERVER_PASS=abcd"
run restart.sh
assert_contains "${OUT}" "at least 5 characters" "4-character password refused"

checkout pass-in-name "SERVER_NAME=Hunter Server" "SERVER_PASS=Hunter"
run restart.sh
assert_contains "${OUT}" "must not appear in SERVER_NAME" "password inside server name refused"

checkout pass-file "SERVER_NAME=x" "SERVER_PASS_FILE=/run/secrets/p"
run restart.sh
assert_eq "${RC}" 0 "SERVER_PASS_FILE skips the password checks"

checkout quoted-pass "SERVER_NAME=x" 'SERVER_PASS="goodpass"'
run restart.sh
assert_eq "${RC}" 0 "quoted password accepted"

section "restart.sh docker calls"
checkout sleep-off "${OK[@]}" "SLEEP_WHEN_IDLE=false"
run restart.sh
assert_eq "${RC}" 0 "sleep off: exits 0"
assert_contains "${CALLS}" "docker compose pull [COMPOSE_FILE= " "sleep off: pulls with the base file only"
assert_contains "${CALLS}" "docker compose up -d --force-recreate --remove-orphans" "always recreates and removes orphans"
assert_contains "${CALLS}" "docker compose logs -f --tail 200" "follows the last 200 log lines"

checkout sleep-on "${OK[@]}" "SLEEP_WHEN_IDLE=true"
run restart.sh
assert_contains "${CALLS}" "up -d --force-recreate --remove-orphans [COMPOSE_FILE=${SLEEP_FILES} M=stop T=1200 P=10]" \
  "sleep on: adds the sleep file with the default settings"

checkout sleep-override "${OK[@]}" "SLEEP_WHEN_IDLE=true"
touch "${DIR}/docker-compose.override.yml"
run restart.sh
assert_contains "${CALLS}" "up -d --force-recreate --remove-orphans [COMPOSE_FILE=${SLEEP_FILES}:docker-compose.override.yml " \
  "sleep on: adds docker-compose.override.yml last when it exists"

checkout sleep-off-override "${OK[@]}" "SLEEP_WHEN_IDLE=false"
touch "${DIR}/docker-compose.override.yml"
run restart.sh
assert_contains "${CALLS}" "up -d --force-recreate --remove-orphans [COMPOSE_FILE= " \
  "sleep off: leaves COMPOSE_FILE unset, so Compose loads the override file itself"

section "sleep settings"
checkout sleep-custom "${OK[@]}" "SLEEP_WHEN_IDLE=true" "SLEEP_METHOD=pause" "SLEEP_AFTER_SECONDS=0900" 'SLEEP_MIN_PACKETS="20"'
run logs.sh
assert_contains "${CALLS}" "M=pause T=0900 P=20" "custom values, leading zero and quotes accepted"

for bad in "SLEEP_METHOD=hibernate|must be stop or pause" \
           "SLEEP_AFTER_SECONDS=299|from 300 to 65535" \
           "SLEEP_AFTER_SECONDS=65536|from 300 to 65535" \
           "SLEEP_AFTER_SECONDS=ten|from 300 to 65535" \
           "SLEEP_MIN_PACKETS=0|from 1 to 65535" \
           "SLEEP_MIN_PACKETS=-5|from 1 to 65535"; do
  setting="${bad%%|*}"
  checkout "bad-${setting//[^a-zA-Z0-9]/_}" "${OK[@]}" "SLEEP_WHEN_IDLE=true" "${setting}"
  run restart.sh
  assert_contains "${OUT}" "${bad#*|}" "${setting} refused"
  assert_eq "${CALLS}" "" "${setting}: no docker calls"
done

checkout sleep-off-ignores "${OK[@]}" "SLEEP_WHEN_IDLE=false" "SLEEP_METHOD=hibernate"
run restart.sh
assert_eq "${RC}" 0 "sleep settings ignored while sleep is off"

section "backup settings"
checkout keep-ok "${OK[@]}" "BACKUPS_KEEP_DAYS=30" "BACKUPS_KEEP_MIN=3" "BACKUPS_MAX_AGE=36500" "BACKUPS_MAX_COUNT=12"
run restart.sh
assert_eq "${RC}" 0 "keep settings with BACKUPS_MAX_AGE=36500: starts"

checkout keep-none "${OK[@]}" "BACKUPS_MAX_AGE=3"
run restart.sh
assert_eq "${RC}" 0 "no keep settings: BACKUPS_MAX_AGE is left to the image"

for bad in "BACKUPS_MAX_AGE=30|set BACKUPS_MAX_AGE=36500" \
           "BACKUPS_MAX_AGE=|set BACKUPS_MAX_AGE=36500" \
           "BACKUPS_KEEP_DAYS=0|at least 1" \
           "BACKUPS_KEEP_DAYS=month|at least 1" \
           "BACKUPS_KEEP_MIN=few|must be a whole number" \
           "BACKUPS_KEEP_MIN=13|larger than BACKUPS_MAX_COUNT (12)"; do
  setting="${bad%%|*}"
  checkout "bad-${setting//[^a-zA-Z0-9]/_}" "${OK[@]}" "BACKUPS_KEEP_DAYS=30" "BACKUPS_KEEP_MIN=3" "BACKUPS_MAX_AGE=36500" "BACKUPS_MAX_COUNT=12" "${setting}"
  run restart.sh
  assert_contains "${OUT}" "${bad#*|}" "${setting:-empty} refused"
  assert_eq "${CALLS}" "" "${setting}: no docker calls"
done

checkout keep-min-only "${OK[@]}" "BACKUPS_KEEP_MIN=3" "BACKUPS_MAX_AGE=3"
run restart.sh
assert_contains "${OUT}" "set BACKUPS_MAX_AGE=36500" "BACKUPS_KEEP_MIN alone also needs the image's limit off"

checkout keep-count-unlimited "${OK[@]}" "BACKUPS_KEEP_DAYS=30" "BACKUPS_KEEP_MIN=50" "BACKUPS_MAX_AGE=36500" "BACKUPS_MAX_COUNT=0"
run restart.sh
assert_eq "${RC}" 0 "BACKUPS_MAX_COUNT=0 (no limit): any BACKUPS_KEEP_MIN accepted"

section "stop.sh, logs.sh, notify-test.sh"
checkout stop-on "${OK[@]}" "SLEEP_WHEN_IDLE=true"
run stop.sh
assert_contains "${CALLS}" "docker compose down --remove-orphans [COMPOSE_FILE=${SLEEP_FILES}" "stop.sh: down with the sleep file"

checkout stop-no-env "${OK[@]}"
rm -- "${DIR}/env/valheim.env"
run stop.sh
assert_eq "${RC}" 0 "stop.sh works without an env file"
assert_contains "${CALLS}" "docker compose down --remove-orphans [COMPOSE_FILE= " "stop.sh without env: base file only"

checkout notify-asleep "${OK[@]}" "SLEEP_WHEN_IDLE=true"
FAKE_ASLEEP=1 run notify-test.sh
assert_eq "${RC}" 1 "notify-test.sh: exits 1 when the server is asleep"
assert_contains "${OUT}" "isn't running, or is asleep" "notify-test.sh: says the server is asleep"
assert_not_contains "${CALLS}" "exec" "notify-test.sh: no exec into a sleeping server"

checkout notify-awake "${OK[@]}"
run notify-test.sh
assert_contains "${CALLS}" "docker compose exec -T valheim /opt/notify/notify.sh test" "notify-test.sh: runs the test inside the container"

section "wipe-restart.sh"
wipe_checkout() {
  checkout "$1" "${OK[@]}" "WORLD_NAME=TestWorld"
  mkdir -p "${DIR}/data/worlds_local/TestWorld" "${DIR}/data/worlds_local/OtherWorld" "${DIR}/backups"
  echo db > "${DIR}/data/worlds_local/TestWorld/world.db"
  echo db > "${DIR}/data/worlds_local/OtherWorld/world.db"
  echo "Steam_1" > "${DIR}/data/adminlist.txt"
  echo zip > "${DIR}/backups/worlds-20260101-000000.zip"
}

wipe_checkout wipe-wrong
run wipe-restart.sh "NotTheName"$'\n'
assert_eq "${RC}" 1 "wrong confirmation: exits 1"
assert_eq "${CALLS}" "" "wrong confirmation: no docker calls"
assert_eq "$(ls "${DIR}/data/worlds_local" | tr '\n' ' ')" "OtherWorld TestWorld " "wrong confirmation: worlds untouched"

wipe_checkout wipe-missing-name
sed -i '/^WORLD_NAME=/d' "${DIR}/env/valheim.env"
run wipe-restart.sh $'x\n'
assert_contains "${OUT}" "WORLD_NAME is not set" "missing WORLD_NAME refused"

if (( EUID != 0 )); then
  wipe_checkout wipe-unwritable
  chmod a-w "${DIR}/data/worlds_local/TestWorld"
  run wipe-restart.sh $'TestWorld\n'
  assert_contains "${OUT}" "is not writable" "unwritable world folder: refused"
  assert_eq "${CALLS}" "" "unwritable world folder: no docker calls"
  assert_eq "$(ls "${DIR}" | grep -c wipe-archives)" 0 "unwritable world folder: nothing archived"
  chmod u+w "${DIR}/data/worlds_local/TestWorld"
else
  pass "unwritable-folder check skipped: running as root"
fi

wipe_checkout wipe-ok
run wipe-restart.sh $'TestWorld\n'
assert_eq "${RC}" 0 "confirmed wipe: exits 0"
archive="$(ls "${DIR}/wipe-archives/"TestWorld-*.tar.gz 2>/dev/null | head -n 1)"
assert_eq "$([[ -f "${archive}" ]] && echo yes)" yes "confirmed wipe: archive written"
assert_contains "$(tar -tzf "${archive}" 2>/dev/null)" "data/worlds_local/OtherWorld/world.db" "archive holds every world"
assert_contains "$(tar -tzf "${archive}" 2>/dev/null)" "backups/worlds-20260101-000000.zip" "archive holds the backups"
assert_eq "$([[ -e "${DIR}/data/worlds_local" ]] && echo present || echo gone)" gone "every world deleted"
assert_eq "$(cat "${DIR}/data/adminlist.txt")" "Steam_1" "admin list kept"
assert_eq "$(ls -A "${DIR}/backups")" "" "backups emptied"
assert_contains "${CALLS}" "docker compose down --remove-orphans" "stops the server first"
assert_contains "${CALLS}" "docker compose up -d --force-recreate --remove-orphans" "then starts it through restart.sh"

finish
