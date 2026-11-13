#!/usr/bin/env bash
# Runs inside the Valheim image; started by tests/image.test.sh, not directly.
# shellcheck source=helpers.sh
source /repo/tests/helpers.sh

LOGFILTER=/usr/local/bin/valheim-logfilter
export IDLE_BACKUPS_MARKER="${TMP_ROOT}/.player-activity"
start_listener "${TMP_ROOT}"
export SERVER_NAME=imagetest NOTIFY_DISCORD_WEBHOOK="http://127.0.0.1:${LISTENER_PORT}/204/token"

section "tools the hooks rely on"
for tool in bash awk curl find sort python3 "${LOGFILTER}"; do
  assert_eq "$(command -v "${tool}" >/dev/null && echo found)" found "${tool} is in the image"
done

section "log filter -> hooks, as configured in env/valheim.env.example"
# feed LINE...: pass log lines through the image's real log filter, with the
# same filters and hook commands as the env example.
feed() {
  # Input stays open for 2 s: the filter runs hooks in the background and
  # exits at end of input without waiting for them.
  { printf '%s\n' "$@"; sleep 2; } | env \
    "VALHEIM_LOG_FILTER_CONTAINS_PlayerSpawned=Got character ZDOID from" \
    "ON_VALHEIM_LOG_FILTER_CONTAINS_PlayerSpawned=/opt/hooks/idle-backups.sh mark; /opt/notify/notify.sh player_spawned" \
    "VALHEIM_LOG_FILTER_CONTAINS_PlayerCount=ZDOS:" \
    "ON_VALHEIM_LOG_FILTER_CONTAINS_PlayerCount=/opt/hooks/idle-backups.sh connections" \
    "${LOGFILTER}" 2>/dev/null
}

OUT="$(NOTIFY_EVENTS=player_spawned feed "11/13/2026 13:10:00: Connections 0 ZDOS:82 sent:0 recv:0")"
assert_contains "${OUT}" "Connections 0 ZDOS:82" "Connections line stays in the log"
assert_eq "$([[ -e "${IDLE_BACKUPS_MARKER}" ]] && echo yes || echo no)" no "Connections 0: no activity recorded"

NOTIFY_EVENTS=player_spawned feed "11/13/2026 13:20:00: Connections 1 ZDOS:85 sent:9 recv:31" >/dev/null
assert_eq "$([[ -e "${IDLE_BACKUPS_MARKER}" ]] && echo yes || echo no)" yes "Connections 1: activity recorded"

rm -f -- "${IDLE_BACKUPS_MARKER}"
OUT="$(NOTIFY_EVENTS=player_spawned feed "11/13/2026 13:30:00: Got character ZDOID from Ragnar : 123:1")"
assert_contains "${OUT}" "Got character ZDOID from Ragnar" "spawn line stays in the log"
assert_eq "$([[ -e "${IDLE_BACKUPS_MARKER}" ]] && echo yes || echo no)" yes "spawn: activity recorded"
assert_contains "$(cat "${TMP_ROOT}/received.jsonl")" "Ragnar spawned into the world." "spawn: notification sent"

section "backup hook, as configured in env/valheim.env.example"
B="${TMP_ROOT}/backups"
mkdir -p "${B}"
: > "${B}/worlds-20261113-100000.zip"
touch -d "2026-11-13 10:00:00" "${B}/worlds-20261113-100000.zip"
touch -d "2026-11-13 09:00:00" "${IDLE_BACKUPS_MARKER}"
: > "${B}/worlds-20261113-110000.zip"
: > "${TMP_ROOT}/received.jsonl"
HOOK='/opt/hooks/idle-backups.sh prune @BACKUP_FILE@ && /opt/notify/notify.sh backup @BACKUP_FILE@ || true'
cmd="${HOOK//@BACKUP_FILE@/${B}/worlds-20261113-110000.zip}"
OUT="$(NOTIFY_EVENTS=backup eval "${cmd}" 2>&1)"
assert_eq "$?" 0 "hook line exits 0, so the image's ERR trap stays quiet"
assert_eq "$(ls "${B}" | tr '\n' ' ')" "worlds-20261113-110000.zip " "idle previous backup deleted"
assert_eq "$(cat "${TMP_ROOT}/received.jsonl")" "" "no notification for a backup that replaced an idle one"

touch "${IDLE_BACKUPS_MARKER}"
sleep 1
: > "${B}/worlds-20261113-120000.zip"
cmd="${HOOK//@BACKUP_FILE@/${B}/worlds-20261113-120000.zip}"
NOTIFY_EVENTS=backup eval "${cmd}" >/dev/null 2>&1
assert_eq "$(ls "${B}" | wc -l)" 2 "after player activity: previous backup kept"
assert_contains "$(cat "${TMP_ROOT}/received.jsonl")" "worlds-20261113-120000.zip" "after player activity: notification sent"

section "age limit with a minimum, then the image's own clean-up"
# The image's real clean-up function, run right after our hook, as in a backup.
# shellcheck source=/dev/null
. /usr/local/etc/valheim/defaults 2>/dev/null
# shellcheck source=/dev/null
. /usr/local/etc/valheim/common 2>/dev/null
eval "$(sed -n '/^flush_old()/,/^}/p' /usr/local/bin/valheim-backup)"
assert_eq "$(type -t flush_old)" function "the image's flush_old loaded"

# backup_round DAYS_OLD... : old backups plus a new one, then the env example's
# hook line and the image's flush_old with the env example's values.
backup_round() {
  local dir="${TMP_ROOT}/round-$1" d
  shift
  mkdir -p "${dir}"
  for d in "$@"; do
    : > "${dir}/worlds-${d}d.zip"
    touch -d "${d} days ago" "${dir}/worlds-${d}d.zip"
  done
  : > "${dir}/worlds-new.zip"
  touch "${IDLE_BACKUPS_MARKER}"
  local example="/repo/env/valheim.env.example" kd km ma mc
  kd="$(sed -n 's/^BACKUPS_KEEP_DAYS=//p' "${example}")"
  km="$(sed -n 's/^BACKUPS_KEEP_MIN=//p' "${example}")"
  ma="$(sed -n 's/^BACKUPS_MAX_AGE=//p' "${example}")"
  mc="$(sed -n 's/^BACKUPS_MAX_COUNT=//p' "${example}")"
  local hook
  hook="$(sed -n 's/^POST_BACKUP_HOOK=//p' "${example}")"
  hook="${hook//@BACKUP_FILE@/${dir}/worlds-new.zip}"
  NOTIFY_EVENTS='' BACKUPS_KEEP_DAYS="${kd}" BACKUPS_KEEP_MIN="${km}" eval "${hook}" >/dev/null 2>&1
  BACKUPS_DIRECTORY="${dir}" BACKUPS_MAX_AGE="${ma}" BACKUPS_MAX_COUNT="${mc}" BACKUPS_ZIP=true flush_old >/dev/null 2>&1
  (cd "${dir}" && ls -t | sed 's/^worlds-//; s/\.zip$//' | tr '\n' ' ')
}

assert_eq "$(backup_round normal 1 2 40 50)" "new 1d 2d " "env example: backups past 30 days removed once 3 newer exist"
assert_eq "$(backup_round long-sleep 40 50 60 70)" "new 40d 50d " "env example: after a long sleep the newest 3 survive the image's clean-up"
assert_eq "$(backup_round many 1 2 3 4 5 6 7 8 9 10 11 12 13)" "new 1d 2d 3d 4d 5d 6d 7d 8d 9d 10d 11d " "env example: BACKUPS_MAX_COUNT still caps the total at 12"

section "Discord adapter with the image's curl"
OUT="$(/opt/notify/notify.sh test 2>&1)"
assert_eq "$?" 0 "test event: exits 0 on success"
OUT="$(NOTIFY_DISCORD_WEBHOOK="http://127.0.0.1:${LISTENER_PORT}/401/token" /opt/notify/notify.sh test 2>&1)"
assert_contains "${OUT}" "discord: HTTP 401: Invalid Webhook Token" "test event: reports the HTTP status and reason"

finish
