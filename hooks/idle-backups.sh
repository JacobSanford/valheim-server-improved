#!/usr/bin/env bash
# Keeps backups taken while nobody plays from pushing out real ones.
#
# Every container start writes a backup, and a running server saves the world
# even when empty, so each restart (and each wake, with sleep when idle) adds a
# backup whose only difference from the last one is idle time. With
# BACKUPS_MAX_COUNT=12, a dozen of those replace every backup of real play.
#
# Runs inside the container, from the image's hooks (see env/valheim.env.example):
#
#   idle-backups.sh mark         a player spawned: record player activity
#   idle-backups.sh connections  the game's "Connections N ZDOS:..." line, logged
#                                every 10 minutes, arrives on stdin: record
#                                player activity if N > 0
#   idle-backups.sh prune FILE   after each backup, two passes:
#                                1. if nobody has played since the previous
#                                   backup, delete that previous one
#                                2. with BACKUPS_KEEP_DAYS set, delete backups
#                                   older than that many days, except the newest
#                                   BACKUPS_KEEP_MIN
#
# The image's own BACKUPS_MAX_AGE deletes old backups unconditionally, so it
# can't keep a minimum. The env example turns it off (36500 days) and leaves the
# age limit to pass 2. The new backup is never deleted, and anything this script
# can't decide, it keeps.
#
# Exit status of prune: 10 when pass 1 deleted the previous backup, otherwise 0.
set -uo pipefail

MARKER="${IDLE_BACKUPS_MARKER:-/config/.player-activity}"

case "${1:-}" in
  mark)
    touch "${MARKER}" 2>/dev/null
    exit 0
    ;;
  connections)
    IFS= read -r line || [[ -n "${line}" ]] || exit 0
    if [[ "${line}" =~ Connections\ ([0-9]+)\  ]] && (( BASH_REMATCH[1] > 0 )); then
      touch "${MARKER}" 2>/dev/null
    fi
    exit 0
    ;;
  prune)
    new="${2:-}"
    ;;
  *)
    echo "usage: idle-backups.sh mark | connections | prune FILE" >&2
    exit 0
    ;;
esac

# Only zip backups (the image's default, BACKUPS_ZIP=true) are handled.
[[ "${new}" == */worlds-*.zip && -f "${new}" ]] || exit 0
dir="$(dirname "${new}")"
status=0

# backups_newest_first: "MTIME PATH" for every zip backup, newest first.
backups_newest_first() {
  find "${dir}" -maxdepth 1 -type f -name 'worlds-*.zip' -printf '%T@ %p\n' | sort -nr
}

# Pass 1: delete the previous backup if nobody has played since it.
prune_idle() {
  local prev
  prev="$(backups_newest_first | grep -v -F " ${new}" | head -n 1 | cut -d ' ' -f 2-)"
  [[ -n "${prev}" ]] || return 0

  # No record yet (first run with this hook): keep everything and start one.
  if [[ ! -e "${MARKER}" ]]; then
    touch "${MARKER}" 2>/dev/null
    return 0
  fi

  # Someone played after the previous backup was written: keep it.
  [[ "${prev}" -nt "${MARKER}" ]] || return 0

  rm -f -- "${prev}" || return 0
  echo "idle-backups: no player activity since $(basename "${prev}"); removed it in favour of $(basename "${new}")"
  status=10
}

# Pass 2: delete backups older than BACKUPS_KEEP_DAYS, except the newest
# BACKUPS_KEEP_MIN. Off unless BACKUPS_KEEP_DAYS is a whole number above 0.
prune_age() {
  local days="${BACKUPS_KEEP_DAYS:-}" keep="${BACKUPS_KEEP_MIN:-0}"
  [[ "${days}" =~ ^[0-9]+$ ]] || return 0
  days=$((10#${days}))
  (( days > 0 )) || return 0
  [[ "${keep}" =~ ^[0-9]+$ ]] || keep=0
  keep=$((10#${keep}))

  local cutoff seen=0 mtime path
  cutoff=$(( $(date +%s) - days * 86400 ))
  while read -r mtime path; do
    seen=$((seen + 1))
    (( seen > keep )) || continue
    [[ "${path}" -ef "${new}" ]] && continue
    (( ${mtime%.*} < cutoff )) || continue
    rm -f -- "${path}" && echo "idle-backups: $(basename "${path}") is older than ${days} days; removed it"
  done < <(backups_newest_first)
}

prune_idle
prune_age
exit "${status}"
