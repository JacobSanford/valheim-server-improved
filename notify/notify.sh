#!/usr/bin/env bash
# Sends one server event to every enabled notification adapter.
# Runs inside the container, called from the image's event hooks (see env/valheim.env.example).
#
# Usage: notify.sh EVENT [ARG]
#   server_up       the server is accepting connections
#   server_down     the server is shutting down
#   restart         the server is restarting for an update or the daily restart
#   backup FILE     a world backup was written to FILE
#   player_spawned  a player spawned in; the matching log line arrives on stdin
#   test            send a test message to every configured adapter (ignores NOTIFY_EVENTS)
#
# Nothing is sent unless the event is listed in NOTIFY_EVENTS (or NOTIFY_EVENTS=all)
# and at least one adapter is configured. A failed send never fails the hook;
# only the test event exits non-zero, so a bad webhook shows up at setup time.
set -uo pipefail

event="${1:-}"
arg="${2:-}"

enabled=",${NOTIFY_EVENTS:-},"
enabled="${enabled// /}"
[[ "${event}" == test || "${enabled}" == *",${event},"* || "${enabled}" == *",all,"* ]] || exit 0

case "${event}" in
  test)        msg="Test notification. If you can read this, notifications work." ;;
  server_up)   msg="Server is up." ;;
  server_down) msg="Server is shutting down." ;;
  restart)     msg="Server is restarting." ;;
  backup)      msg="World backup created: ${arg##*/}" ;;
  player_spawned)
    IFS= read -r line || [[ -n "${line}" ]] || exit 0
    # Log line: "... Got character ZDOID from <name> : <id>:<n>". An id of 0:0 is a death, not a spawn.
    [[ "${line}" == *" : 0:0"* ]] && exit 0
    name="${line##*ZDOID from }"
    name="${name% : *}"
    msg="${name} spawned into the world."
    ;;
  *)
    echo "notify: unknown event '${event}'" >&2
    exit 0
    ;;
esac

sent=0
failed=0
for adapter in "$(dirname "$0")"/adapters/*.sh; do
  [[ -f "${adapter}" ]] || continue
  name="$(basename "${adapter}" .sh)"
  # Each adapter runs in a subshell: 0 sent, 1 failed, 2 not configured.
  (
    # shellcheck source=/dev/null  # adapters are found at run time
    source "${adapter}"
    adapter_enabled || exit 2
    adapter_send "${event}" "${msg}"
  )
  case $? in
    0) sent=$((sent + 1)); [[ "${event}" == test ]] && echo "notify: ${name}: sent" ;;
    2) ;;
    *) failed=$((failed + 1)); echo "notify: ${name}: failed to send '${event}'" >&2 ;;
  esac
done

if [[ "${event}" == test ]]; then
  (( sent + failed > 0 )) || { echo "notify: no adapter is configured. Set NOTIFY_DISCORD_WEBHOOK in env/valheim.env." >&2; exit 1; }
  (( failed == 0 )) || exit 1
fi
exit 0
