# shellcheck shell=bash
# Discord adapter. Enabled when NOTIFY_DISCORD_WEBHOOK is set.
#
# An adapter is a file in this directory that defines two functions:
#   adapter_enabled         exit 0 if the adapter is configured
#   adapter_send EVENT MSG  deliver MSG; exit non-zero on failure

adapter_enabled() {
  [[ -n "${NOTIFY_DISCORD_WEBHOOK:-}" ]]
}

_discord_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  printf '%s' "${s}"
}

adapter_send() {
  local username="${NOTIFY_DISCORD_USERNAME:-${SERVER_NAME:-Valheim}}"
  # allowed_mentions: a player named "@everyone" must not ping the channel.
  local body
  body="{\"username\":\"$(_discord_json_escape "${username}")\",\"content\":\"$(_discord_json_escape "$2")\",\"allowed_mentions\":{\"parse\":[]}}"
  # On failure, report the HTTP status and Discord's reason, never the URL: it contains the webhook's secret token.
  local resp code reason
  resp="$(curl -sS --max-time 10 -w $'\n%{http_code}' -X POST -H "Content-Type: application/json" -d "${body}" "${NOTIFY_DISCORD_WEBHOOK}")" || return 1
  code="${resp##*$'\n'}"
  [[ "${code}" == 2* ]] && return 0
  reason="$(printf '%s' "${resp%$'\n'*}" | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p')"
  echo "discord: HTTP ${code}${reason:+: ${reason}}" >&2
  return 1
}
