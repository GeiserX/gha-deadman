#!/usr/bin/env bash
# Mocked tests for scripts/check.sh: fake curl/gh via PATH shims, assert the
# run-history state machine sends the right alerts with the right exit codes.
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
echo "GH_RUNS" >>"$MOCK_LOG"
if [[ -n "${MOCK_HIST:-}" ]]; then printf '%s\n' "${MOCK_HIST//;/$'\n'}"; fi
exit 0
EOF
chmod +x "$TMP/curl" "$TMP/gh"

run_case() { # name, expected_rc
  local name="$1" expected_rc="$2" rc=0
  : >"$LOG"
  MOCK_LOG="$LOG" CURL="$TMP/curl" GH="$TMP/gh" \
    TARGET_URL="https://example.com/x" TELEGRAM_BOT_TOKEN=t TELEGRAM_CHAT_ID=c \
    GH_TOKEN=g GH_REPO=o/r PROBE_RETRY_DELAY=0 NOW_OVERRIDE=1786831200 \
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

# NOW_OVERRIDE=1786831200 is 2026-08-15T22:00:00Z; fixture timestamps sit before it.

# A: no history, probe fails twice -> transition alert, rc=1, exactly 2 attempts
MOCK_PROBE_RC=1 MOCK_HIST="" run_case "fresh-down" 1
assert_log "fresh-down" "^PROBE$" 2
assert_log "fresh-down" "TELEGRAM.*UNREACHABLE" 1

# B: was down (streak 2, oldest 21:00Z), probe ok -> recovery with ~60 min, rc=0
MOCK_PROBE_RC=0 MOCK_HIST="failure 2026-08-15T21:10:00Z;failure 2026-08-15T21:00:00Z;success 2026-08-15T20:50:00Z" run_case "recovery" 0
assert_log "recovery" "TELEGRAM.*reachable again.*down ~60 min" 1

# C: steady up -> silent, rc=0
MOCK_PROBE_RC=0 MOCK_HIST="success 2026-08-15T21:50:00Z;success 2026-08-15T21:40:00Z" run_case "steady-up" 0
assert_log "steady-up" "TELEGRAM" 0

# D: down, streak 1 (total 2, not a multiple of 6) -> silent red, rc=1
MOCK_PROBE_RC=1 MOCK_HIST="failure 2026-08-15T21:50:00Z;success 2026-08-15T21:40:00Z" run_case "down-quiet" 1
assert_log "down-quiet" "TELEGRAM" 0

# E: down, streak 5 (total 6) -> hourly re-alert with duration, rc=1
MOCK_PROBE_RC=1 MOCK_HIST="failure 2026-08-15T21:50:00Z;failure 2026-08-15T21:40:00Z;failure 2026-08-15T21:30:00Z;failure 2026-08-15T21:20:00Z;failure 2026-08-15T21:10:00Z;success 2026-08-15T21:00:00Z" run_case "down-realert" 1
assert_log "down-realert" "TELEGRAM.*still unreachable.*down ~50 min" 1

# F: no history, probe ok -> silent, rc=0
MOCK_PROBE_RC=0 MOCK_HIST="" run_case "fresh-up" 0
assert_log "fresh-up" "TELEGRAM" 0

# Harness positive control: a wrong expectation must fail (run in subshell)
if (MOCK_PROBE_RC=0 MOCK_HIST="" run_case "control" 1) 2>/dev/null; then
  echo "FAIL [control]: harness cannot detect failures"; exit 1
fi

echo "ALL TESTS PASSED"
