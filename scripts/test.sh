#!/usr/bin/env bash
# Mocked tests for scripts/check.sh: fake curl/gh via PATH shims, assert the
# state machine sends the right alerts and writes the right state.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"

cat >"$TMP/curl" <<'EOF'
#!/usr/bin/env bash
args="$*"
if [[ "$args" == *api.telegram.org* ]]; then
  echo "TELEGRAM $args" >>"$MOCK_LOG"
  exit 0
fi
echo "PROBE" >>"$MOCK_LOG"
exit "${MOCK_PROBE_RC:-0}"
EOF

cat >"$TMP/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"
if [[ "$args" == *"-X PATCH"* ]]; then
  echo "GH_PATCH $args" >>"$MOCK_LOG"
  exit "${MOCK_PATCH_RC:-0}"
elif [[ "$args" == *"-X POST"* ]]; then
  echo "GH_POST $args" >>"$MOCK_LOG"
  exit 0
else
  echo "GH_GET" >>"$MOCK_LOG"
  if [[ -n "${MOCK_STATE:-}" ]]; then echo "$MOCK_STATE"; exit 0; else exit 1; fi
fi
EOF
chmod +x "$TMP/curl" "$TMP/gh"

run_case() { # name, expected_rc
  local name="$1" expected_rc="$2" rc=0
  : >"$LOG"
  MOCK_LOG="$LOG" CURL="$TMP/curl" GH="$TMP/gh" \
    TARGET_URL="https://example.com/x" TELEGRAM_BOT_TOKEN=t TELEGRAM_CHAT_ID=c \
    GH_TOKEN=g GH_REPO=o/r PROBE_RETRY_DELAY=0 NOW_OVERRIDE=1000000 \
    bash scripts/check.sh >"$TMP/out" 2>&1 || rc=$?
  if [[ "$rc" != "$expected_rc" ]]; then
    echo "FAIL [$name]: rc=$rc expected=$expected_rc"; cat "$TMP/out"; cat "$LOG"; exit 1
  fi
}

assert_log() { # name, pattern, expected_count
  local n
  n="$(grep -c "$2" "$LOG" || true)"
  if [[ "$n" != "$3" ]]; then
    echo "FAIL [$1]: pattern '$2' count=$n expected=$3"; cat "$LOG"; exit 1
  fi
}

# Case A: no prior state, probe fails twice -> down alert + state created, rc=1
MOCK_PROBE_RC=1 MOCK_STATE="" run_case "fresh-down" 1
assert_log "fresh-down" "^PROBE$" 2
assert_log "fresh-down" "TELEGRAM.*UNREACHABLE" 1
assert_log "fresh-down" 'GH_.*state.*down' 1

# Case B: was down, probe succeeds -> recovery alert + state up, rc=0
MOCK_PROBE_RC=0 MOCK_STATE='{"state":"down","since":999400,"last_alert":999400}' run_case "recovery" 0
assert_log "recovery" "TELEGRAM.*reachable again" 1
assert_log "recovery" 'GH_PATCH.*state.*up' 1

# Case C: steady up -> silent, no writes, rc=0
MOCK_PROBE_RC=0 MOCK_STATE='{"state":"up","since":999400,"last_alert":0}' run_case "steady-up" 0
assert_log "steady-up" "TELEGRAM" 0
assert_log "steady-up" "GH_PATCH\|GH_POST" 0

# Case D: still down within re-alert window -> silent, rc=1
MOCK_PROBE_RC=1 MOCK_STATE='{"state":"down","since":999400,"last_alert":999900}' run_case "down-quiet" 1
assert_log "down-quiet" "TELEGRAM" 0

# Case E: still down past re-alert window -> re-alert, rc=1
MOCK_PROBE_RC=1 MOCK_STATE='{"state":"down","since":990000,"last_alert":996000}' run_case "down-realert" 1
assert_log "down-realert" "TELEGRAM.*still unreachable" 1

# Harness positive control: a wrong expectation must fail (run in subshell)
if (MOCK_PROBE_RC=0 MOCK_STATE='{"state":"up","since":1,"last_alert":0}' run_case "control" 1) 2>/dev/null; then
  echo "FAIL [control]: harness cannot detect failures"; exit 1
fi

echo "ALL TESTS PASSED"
