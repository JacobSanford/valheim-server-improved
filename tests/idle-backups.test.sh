#!/usr/bin/env bash
# hooks/idle-backups.sh with stand-in backup files and a temporary marker.
source "$(dirname "$0")/helpers.sh"

HOOK="${REPO}/hooks/idle-backups.sh"
B="${TMP_ROOT}/backups"
mkdir -p "${B}"
export IDLE_BACKUPS_MARKER="${TMP_ROOT}/.player-activity"

# backup NAME TIME: a stand-in backup file with that modification time.
backup() {
  : > "${B}/worlds-$1.zip"
  touch -d "2026-11-13 $2" "${B}/worlds-$1.zip"
}

# prune NAME: run the hook for that backup. Sets RC, OUT and LEFT.
prune() {
  OUT="$("${HOOK}" prune "${B}/worlds-$1.zip" 2>&1)"
  RC=$?
  LEFT="$(cd "${B}" && ls | sed 's/^worlds-//; s/\.zip$//' | tr '\n' ' ')"
}

marker_time() { date -r "${IDLE_BACKUPS_MARKER}" +%H:%M:%S 2>/dev/null || echo none; }

section "prune"
backup 01 10:00:00
prune 01
assert_eq "${RC} | ${LEFT}" "0 | 01 " "first backup ever: kept, nothing to compare"

backup 02 11:00:00
prune 02
assert_eq "${RC} | ${LEFT}" "0 | 01 02 " "no marker yet: keeps everything"
assert_eq "$([[ -e "${IDLE_BACKUPS_MARKER}" ]] && echo yes)" yes "no marker yet: starts one"

touch -d "2026-11-13 11:30:00" "${IDLE_BACKUPS_MARKER}"
backup 03 12:00:00
prune 03
assert_eq "${RC} | ${LEFT}" "0 | 01 02 03 " "activity since the previous backup: previous kept"

backup 04 13:00:00
prune 04
assert_eq "${RC} | ${LEFT}" "10 | 01 02 04 " "no activity since the previous backup: previous deleted, exit 10"
assert_contains "${OUT}" "removed it in favour of worlds-04.zip" "says which backup it removed"

backup 05 14:00:00
prune 05
assert_eq "${LEFT}" "01 02 05 " "idle backups keep replacing each other"

touch -d "2026-11-13 14:00:00" "${IDLE_BACKUPS_MARKER}"
backup 06 15:00:00
prune 06
assert_eq "${LEFT}" "01 02 05 06 " "marker at the same second as the previous backup: kept"

section "age limit with a minimum (BACKUPS_KEEP_DAYS, BACKUPS_KEEP_MIN)"
# age_case NAME DAYS_OLD...: a fresh folder with one backup per age (in days),
# plus a new backup written now. The marker is current, so pass 1 keeps
# everything and only pass 2 decides. Sets AB (the folder).
age_case() {
  AB="${TMP_ROOT}/age-$1"
  shift
  mkdir -p "${AB}"
  local d
  for d in "$@"; do
    : > "${AB}/worlds-${d}d.zip"
    touch -d "${d} days ago" "${AB}/worlds-${d}d.zip"
  done
  : > "${AB}/worlds-new.zip"
  touch "${IDLE_BACKUPS_MARKER}"
}
# age_prune [VAR=VALUE...]: run pass 2 on AB's new backup. Sets RC, OUT, LEFT.
age_prune() {
  OUT="$(env "$@" "${HOOK}" prune "${AB}/worlds-new.zip" 2>&1)"
  RC=$?
  LEFT="$(cd "${AB}" && ls -t | sed 's/^worlds-//; s/\.zip$//' | tr '\n' ' ')"
}

age_case off 1 40 50
age_prune
assert_eq "${LEFT}" "new 1d 40d 50d " "BACKUPS_KEEP_DAYS unset: nothing deleted for age"

age_case normal 1 2 40 50 60
age_prune BACKUPS_KEEP_DAYS=30 BACKUPS_KEEP_MIN=3
assert_eq "${LEFT}" "new 1d 2d " "older than 30 days deleted once 3 newer ones exist"
assert_contains "${OUT}" "worlds-60d.zip is older than 30 days; removed it" "logs each removal"
assert_eq "${RC}" 0 "age removals alone: exits 0, so the backup is still announced"

age_case long-sleep 40 50 60 70
age_prune BACKUPS_KEEP_DAYS=30 BACKUPS_KEEP_MIN=3
assert_eq "${LEFT}" "new 40d 50d " "after a long sleep: the newest 3 kept however old"

age_case keep-zero 40 50
age_prune BACKUPS_KEEP_DAYS=30 BACKUPS_KEEP_MIN=0
assert_eq "${LEFT}" "new " "BACKUPS_KEEP_MIN=0: only the new backup survives"

age_case keep-unset 40 50
age_prune BACKUPS_KEEP_DAYS=30
assert_eq "${LEFT}" "new " "BACKUPS_KEEP_MIN unset counts as 0"

age_case new-is-old 40
touch -d "100 days ago" "${AB}/worlds-new.zip"
age_prune BACKUPS_KEEP_DAYS=30 BACKUPS_KEEP_MIN=0
assert_contains "${LEFT}" "new" "the new backup is never deleted, whatever its date"

age_case bad-days 40 50
age_prune BACKUPS_KEEP_DAYS=abc BACKUPS_KEEP_MIN=1
assert_eq "${LEFT}" "new 40d 50d " "BACKUPS_KEEP_DAYS not a number: nothing deleted"

age_case zero-days 40
age_prune BACKUPS_KEEP_DAYS=0
assert_eq "${LEFT}" "new 40d " "BACKUPS_KEEP_DAYS=0: off"

age_case leading-zero 1 40
age_prune BACKUPS_KEEP_DAYS=030 BACKUPS_KEEP_MIN=01
assert_eq "${LEFT}" "new 1d " "leading zeros read as decimal"

age_case both-passes 40 50
touch -d "1 hour ago" "${IDLE_BACKUPS_MARKER}"
touch -d "10 minutes ago" "${AB}/worlds-40d.zip"
age_prune BACKUPS_KEEP_DAYS=30 BACKUPS_KEEP_MIN=1
assert_eq "${RC}" 10 "idle pass deletes the previous backup: still exits 10"
assert_eq "${LEFT}" "new " "then the age pass removes the old one past the minimum"

section "unusual input"
"${HOOK}" prune "${B}/worlds-missing.zip"
assert_eq "$?" 0 "missing file: exits 0"
: > "${B}/AUTOBACKUP-x.db"
"${HOOK}" prune "${B}/AUTOBACKUP-x.db"
assert_eq "$?" 0 "non-zip backup (BACKUPS_ZIP=false): exits 0, untouched"
OUT="$("${HOOK}" nonsense 2>&1)"
assert_eq "$?" 0 "unknown subcommand: exits 0"
assert_contains "${OUT}" "usage:" "unknown subcommand: prints usage"

section "activity"
touch -d "2026-11-13 09:00:00" "${IDLE_BACKUPS_MARKER}"
"${HOOK}" mark
assert_eq "$(( $(date +%s) - $(date -r "${IDLE_BACKUPS_MARKER}" +%s) < 5 ))" 1 "mark: touches the marker"

touch -d "2026-11-13 09:00:00" "${IDLE_BACKUPS_MARKER}"
printf '%s\n' "11/13/2026 13:10:00: Connections 0 ZDOS:82 sent:0 recv:0" | "${HOOK}" connections
assert_eq "$(marker_time)" "09:00:00" "Connections 0: marker unchanged"
printf '%s' "11/13/2026 13:20:00: Connections 2 ZDOS:90 sent:12 recv:40" | "${HOOK}" connections
assert_eq "$(( $(date +%s) - $(date -r "${IDLE_BACKUPS_MARKER}" +%s) < 5 ))" 1 "Connections 2 (no trailing newline): marker touched"

touch -d "2026-11-13 09:00:00" "${IDLE_BACKUPS_MARKER}"
printf '%s\n' "11/13/2026 13:30:00: Connections 12 ZDOS:90 sent:12 recv:40" | "${HOOK}" connections
assert_eq "$(( $(date +%s) - $(date -r "${IDLE_BACKUPS_MARKER}" +%s) < 5 ))" 1 "Connections 12: marker touched"

touch -d "2026-11-13 09:00:00" "${IDLE_BACKUPS_MARKER}"
printf '%s\n' "some other line mentioning ZDOS:" | "${HOOK}" connections
assert_eq "$(marker_time)" "09:00:00" "unrelated line: marker unchanged"

"${HOOK}" connections < /dev/null
assert_eq "$?" 0 "no input: exits 0"

finish
