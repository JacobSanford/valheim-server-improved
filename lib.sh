# shellcheck shell=bash
# Shared helpers, sourced by the scripts in this directory. Not meant to be run.

ENV_FILE="env/valheim.env"

die() {
  echo "$*" >&2
  exit 1
}

require_env_file() {
  [[ -f "${ENV_FILE}" ]] || die "${ENV_FILE} not found. Copy env/valheim.env.example to it first."
}

# env_value NAME: the last NAME= value in ENV_FILE, minus one pair of surrounding quotes.
env_value() {
  local v
  v="$(sed -n "s/^$1=//p" "${ENV_FILE}" | tail -n 1)"
  v="${v%\"}"; v="${v#\"}"
  v="${v%\'}"; v="${v#\'}"
  printf '%s' "${v}"
}

# compose_setup: point every later `docker compose` call at the right files.
# With SLEEP_WHEN_IDLE=true, docker-compose.sleep.yml is added on top, and the
# sleep settings are exported for its ${...} labels. Without an env file it does
# nothing, so stop.sh and logs.sh still work on a half-set-up checkout.
compose_setup() {
  [[ -f "${ENV_FILE}" ]] || return 0
  [[ "$(env_value SLEEP_WHEN_IDLE)" == "true" ]] || return 0

  SLEEP_METHOD="$(env_value SLEEP_METHOD)"
  SLEEP_METHOD="${SLEEP_METHOD:-stop}"
  [[ "${SLEEP_METHOD}" == "stop" || "${SLEEP_METHOD}" == "pause" ]] \
    || die "SLEEP_METHOD in ${ENV_FILE} must be stop or pause, not '${SLEEP_METHOD}'."

  SLEEP_AFTER_SECONDS="$(env_value SLEEP_AFTER_SECONDS)"
  SLEEP_AFTER_SECONDS="${SLEEP_AFTER_SECONDS:-1200}"
  # Shorter than a wake (about a minute, longer with a game update) and the
  # server would be stopped again while it is still starting. Lazytainer
  # stores both numbers as 16-bit values, hence the upper bounds.
  if [[ ! "${SLEEP_AFTER_SECONDS}" =~ ^[0-9]+$ ]] || (( 10#${SLEEP_AFTER_SECONDS} < 300 || 10#${SLEEP_AFTER_SECONDS} > 65535 )); then
    die "SLEEP_AFTER_SECONDS in ${ENV_FILE} must be a whole number of seconds from 300 to 65535."
  fi

  SLEEP_MIN_PACKETS="$(env_value SLEEP_MIN_PACKETS)"
  SLEEP_MIN_PACKETS="${SLEEP_MIN_PACKETS:-10}"
  if [[ ! "${SLEEP_MIN_PACKETS}" =~ ^[0-9]+$ ]] || (( 10#${SLEEP_MIN_PACKETS} < 1 || 10#${SLEEP_MIN_PACKETS} > 65535 )); then
    die "SLEEP_MIN_PACKETS in ${ENV_FILE} must be a whole number from 1 to 65535."
  fi

  export SLEEP_METHOD SLEEP_AFTER_SECONDS SLEEP_MIN_PACKETS
  export COMPOSE_FILE="docker-compose.yml:docker-compose.sleep.yml"
}

# check_backup_settings: refuse settings under which BACKUPS_KEEP_MIN can't work.
# The image deletes backups older than BACKUPS_MAX_AGE days with no exceptions,
# so with our own age limit in use, its limit has to be off (36500 days).
check_backup_settings() {
  local days keep max_age max_count
  days="$(env_value BACKUPS_KEEP_DAYS)"
  keep="$(env_value BACKUPS_KEEP_MIN)"
  [[ -n "${days}${keep}" ]] || return 0

  if [[ -n "${days}" ]] && { [[ ! "${days}" =~ ^[0-9]+$ ]] || (( 10#${days} < 1 )); }; then
    die "BACKUPS_KEEP_DAYS in ${ENV_FILE} must be a whole number of days, at least 1."
  fi
  if [[ -n "${keep}" && ! "${keep}" =~ ^[0-9]+$ ]]; then
    die "BACKUPS_KEEP_MIN in ${ENV_FILE} must be a whole number."
  fi

  max_age="$(env_value BACKUPS_MAX_AGE)"
  max_age="${max_age:-3}"
  if [[ ! "${max_age}" =~ ^[0-9]+$ ]] || (( 10#${max_age} < 36500 )); then
    die "With BACKUPS_KEEP_DAYS or BACKUPS_KEEP_MIN set, set BACKUPS_MAX_AGE=36500 in ${ENV_FILE}. Otherwise the image deletes old backups itself, including the ones BACKUPS_KEEP_MIN should keep."
  fi

  max_count="$(env_value BACKUPS_MAX_COUNT)"
  if [[ -n "${keep}" && "${max_count}" =~ ^[0-9]+$ ]] && (( 10#${max_count} > 0 && 10#${keep} > 10#${max_count} )); then
    die "BACKUPS_KEEP_MIN (${keep}) is larger than BACKUPS_MAX_COUNT (${max_count}) in ${ENV_FILE}. The image never keeps more than BACKUPS_MAX_COUNT."
  fi
}
