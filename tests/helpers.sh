# shellcheck shell=bash
# Shared test helpers, sourced by tests/*.test.sh. Plain bash, no dependencies
# beyond coreutils and python3.

set -uo pipefail

# shellcheck disable=SC2034  # REPO, LISTENER_PORT and LISTENER_PID are used by the test files
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSED=0
FAILED=0

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "${TMP_ROOT}"' EXIT

pass() {
  PASSED=$((PASSED + 1))
  printf '  ok    %s\n' "$1"
}

fail() {
  FAILED=$((FAILED + 1))
  printf '  FAIL  %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/          /'
  fi
}

# assert_eq ACTUAL EXPECTED NAME
assert_eq() {
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3" "expected: $2"$'\n'"actual:   $1"; fi
}

# assert_contains HAYSTACK NEEDLE NAME
assert_contains() {
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3" "expected to contain: $2"$'\n'"actual: $1"; fi
}

# assert_not_contains HAYSTACK NEEDLE NAME
assert_not_contains() {
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3" "expected not to contain: $2"$'\n'"actual: $1"; fi
}

# section TITLE
section() {
  printf '%s\n' "$1"
}

# finish: print the totals and exit non-zero if anything failed.
finish() {
  printf '%s: %d passed, %d failed\n' "$(basename "$0")" "${PASSED}" "${FAILED}"
  (( FAILED == 0 ))
}

# start_listener DIR: an HTTP server standing in for a webhook. A POST to
# /<code>/... is answered with that status code and the body recorded in
# DIR/received.jsonl. Path /hang/... never answers. Sets LISTENER_PORT and
# LISTENER_PID.
start_listener() {
  local dir="$1"
  : > "${dir}/received.jsonl"
  python3 -I - "${dir}" > "${dir}/port" 2>/dev/null <<'PY' &
import http.server, json, sys, time
out = sys.argv[1] + "/received.jsonl"
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        part = self.path.strip("/").split("/")[0]
        if part == "hang":
            time.sleep(60)
            return
        try:
            rec = json.loads(body)
        except Exception as e:
            rec = {"INVALID_JSON": body.decode(errors="replace")}
        with open(out, "a") as f:
            f.write(json.dumps(rec) + "\n")
        code = int(part)
        self.send_response(code)
        self.end_headers()
        if code >= 400:
            self.wfile.write(b'{"message": "Invalid Webhook Token", "code": 50027}')
    def log_message(self, *a):
        pass
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
s.serve_forever()
PY
  LISTENER_PID=$!
  local _
  for _ in $(seq 1 50); do
    [[ -s "${dir}/port" ]] && break
    sleep 0.1
  done
  # shellcheck disable=SC2034  # used by the test files
  LISTENER_PORT="$(cat "${dir}/port")"
  # shellcheck disable=SC2064  # expand now: stop this listener at exit
  trap "kill ${LISTENER_PID} 2>/dev/null; rm -rf -- '${TMP_ROOT}'" EXIT
}
