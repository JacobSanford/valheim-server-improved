#!/usr/bin/env bash
# notify/notify.sh and the Discord adapter, posting to a local stand-in for the
# Discord webhook (see start_listener in helpers.sh).
source "$(dirname "$0")/helpers.sh"

NOTIFY="${REPO}/notify/notify.sh"
start_listener "${TMP_ROOT}"
URL="http://127.0.0.1:${LISTENER_PORT}"
TOKEN="secret-token-value"

# send EVENT [ARG] [STDIN] with the environment set by the caller.
# Sets OUT (stdout+stderr), RC and NEW (records received by this call).
send() {
  local before
  before="$(wc -l < "${TMP_ROOT}/received.jsonl")"
  OUT="$(printf '%s' "${3:-}" | "${NOTIFY}" "$1" ${2:+"$2"} 2>&1)"
  RC=$?
  NEW="$(tail -n +"$((before + 1))" "${TMP_ROOT}/received.jsonl")"
}

json() { python3 -c "import json,sys; d=json.loads(sys.stdin.readline()); print($1)"; }

section "events are off unless listed"
export SERVER_NAME=t NOTIFY_DISCORD_WEBHOOK="${URL}/204/${TOKEN}"
NOTIFY_EVENTS='' send server_up
assert_eq "${NEW}" "" "NOTIFY_EVENTS empty: nothing sent"
NOTIFY_EVENTS=backup send server_up
assert_eq "${NEW}" "" "event not listed: nothing sent"
NOTIFY_DISCORD_WEBHOOK='' NOTIFY_EVENTS=all send server_up
assert_eq "${NEW}" "" "no webhook: nothing sent"
NOTIFY_EVENTS=all send bogus_event
assert_eq "${RC}" 0 "unknown event: exits 0"

section "messages"
export NOTIFY_EVENTS="server_up, server_down ,restart,backup,player_spawned"
send server_up
assert_eq "$(json "d['content']" <<< "${NEW}")" "Server is up." "server_up message (spaces in NOTIFY_EVENTS ignored)"
send server_down
assert_eq "$(json "d['content']" <<< "${NEW}")" "Server is shutting down." "server_down message"
send restart
assert_eq "$(json "d['content']" <<< "${NEW}")" "Server is restarting." "restart message"
send backup /config/backups/worlds-20261113-102908.zip
assert_eq "$(json "d['content']" <<< "${NEW}")" "World backup created: worlds-20261113-102908.zip" "backup message names the file"
send player_spawned "" '11/13/2026 10:40:01: Got character ZDOID from Ragnar : 123456789:1'
assert_eq "$(json "d['content']" <<< "${NEW}")" "Ragnar spawned into the world." "player_spawned names the player"
send player_spawned "" $'11/13/2026 10:40:02: Got character ZDOID from Sigrid : 5:1\n'
assert_eq "$(json "d['content']" <<< "${NEW}")" "Sigrid spawned into the world." "log line with or without a trailing newline"
send player_spawned "" '11/13/2026 10:41:01: Got character ZDOID from Ragnar : 0:0'
assert_eq "${NEW}" "" "a death (0:0) is not a spawn"
NOTIFY_EVENTS=all send server_up
assert_contains "${NEW}" "Server is up." "NOTIFY_EVENTS=all"

section "escaping and mentions"
SERVER_NAME='My "Quoted" \Server' send player_spawned "" $'x: Got character ZDOID from @everyone "the"\tbold : 1:1'
assert_eq "$(json "d['username']" <<< "${NEW}")" 'My "Quoted" \Server' "username with quotes and backslash is valid JSON"
assert_eq "$(json "d['content']" <<< "${NEW}")" $'@everyone "the"\tbold spawned into the world.' "content with quotes and a tab is valid JSON"
assert_eq "$(json "d['allowed_mentions']" <<< "${NEW}")" "{'parse': []}" "mentions disabled, so @everyone can't ping"
NOTIFY_DISCORD_USERNAME=Bot send server_up
assert_eq "$(json "d['username']" <<< "${NEW}")" "Bot" "NOTIFY_DISCORD_USERNAME overrides the server name"

section "failures never fail the hook, and never print the token"
for case in "401|${URL}/401/${TOKEN}|discord: HTTP 401: Invalid Webhook Token" \
            "404|${URL}/404/${TOKEN}|discord: HTTP 404" \
            "500|${URL}/500/${TOKEN}|discord: HTTP 500" \
            "malformed URL|not a url ${TOKEN}|failed to send" \
            "connection refused|http://127.0.0.1:1/${TOKEN}|failed to send"; do
  IFS='|' read -r label url expected <<< "${case}"
  NOTIFY_DISCORD_WEBHOOK="${url}" send server_up
  assert_eq "${RC}" 0 "${label}: hook still exits 0"
  assert_contains "${OUT}" "${expected}" "${label}: reason printed"
  assert_not_contains "${OUT}" "${TOKEN}" "${label}: token not printed"
done

start=$(date +%s)
NOTIFY_DISCORD_WEBHOOK="${URL}/hang/${TOKEN}" send server_up
took=$(( $(date +%s) - start ))
assert_eq "${RC}" 0 "server that never answers: hook still exits 0"
assert_eq "$(( took >= 9 && took <= 15 ))" 1 "server that never answers: gives up after about 10 seconds (took ${took}s)"

section "the test event"
NOTIFY_EVENTS='' send test
assert_eq "${RC}" 0 "test: exits 0 on success, even with NOTIFY_EVENTS empty"
assert_contains "${OUT}" "notify: discord: sent" "test: reports the send"
NOTIFY_DISCORD_WEBHOOK="${URL}/401/${TOKEN}" send test
assert_eq "${RC}" 1 "test: exits 1 when the webhook is rejected"
NOTIFY_DISCORD_WEBHOOK='' send test
assert_eq "${RC}" 1 "test: exits 1 with no adapter configured"
assert_contains "${OUT}" "no adapter is configured" "test: says no adapter is configured"

finish
