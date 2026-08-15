#!/usr/bin/env bash
# gha-deadman: probe TARGET_URL and alert on Telegram. Stateless by design —
# the workflow's own run history IS the state: the previous completed run's
# conclusion says whether we were up or down, the streak of consecutive
# failures drives hourly re-alerts, and the oldest failure's timestamp gives
# the outage duration. Nothing is stored anywhere.
set -euo pipefail

: "${TARGET_URL:?}" "${TELEGRAM_BOT_TOKEN:?}" "${TELEGRAM_CHAT_ID:?}" "${GH_TOKEN:?}" "${GH_REPO:?}"
WORKFLOW_FILE="${WORKFLOW_FILE:-deadman.yml}"
REALERT_EVERY_RUNS="${REALERT_EVERY_RUNS:-6}" # 6 runs x 10 min cron = hourly reminders
PROBE_ATTEMPTS="${PROBE_ATTEMPTS:-2}"
PROBE_TIMEOUT="${PROBE_TIMEOUT:-20}"
PROBE_RETRY_DELAY="${PROBE_RETRY_DELAY:-25}"
CURL="${CURL:-curl}"
GH="${GH:-gh}"
NOW="${NOW_OVERRIDE:-$(date +%s)}"

probe() {
  local i
  for ((i = 1; i <= PROBE_ATTEMPTS; i++)); do
    if "$CURL" -fsS -m "$PROBE_TIMEOUT" -o /dev/null "$TARGET_URL"; then
      return 0
    fi
    ((i < PROBE_ATTEMPTS)) && sleep "$PROBE_RETRY_DELAY"
  done
  return 1
}

tg() {
  "$CURL" -fsS -m 20 -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" --data-urlencode text="$1"
  echo "telegram: sent"
}

# "conclusion created_at" lines for this workflow's completed runs, newest first
get_history() {
  "$GH" api "repos/$GH_REPO/actions/workflows/$WORKFLOW_FILE/runs?status=completed&per_page=40" \
    -q '.workflow_runs[] | select(.conclusion == "success" or .conclusion == "failure") | .conclusion + " " + .created_at' \
    2>/dev/null || true
}

iso2epoch() {
  jq -rn --arg t "$1" '$t | fromdateiso8601'
}

main() {
  local prev="" streak=0 oldest_fail_ts="" counting=1 concl ts mins total
  while IFS=' ' read -r concl ts; do
    [[ -z "$concl" ]] && continue
    [[ -z "$prev" ]] && prev="$concl"
    if ((counting)); then
      if [[ "$concl" == "failure" ]]; then
        streak=$((streak + 1))
        oldest_fail_ts="$ts"
      else
        counting=0
      fi
    fi
  done <<<"$(get_history)"
  prev="${prev:-success}"

  if probe; then
    if [[ "$prev" == "failure" ]]; then
      mins=$(((NOW - $(iso2epoch "$oldest_fail_ts")) / 60))
      tg "🟢 deadman: ${TARGET_URL} is reachable again (was down ~${mins} min)"
    fi
    echo "status: up"
  else
    total=$((streak + 1))
    if [[ "$prev" != "failure" ]]; then
      tg "🔴 deadman: ${TARGET_URL} is UNREACHABLE from GitHub (${PROBE_ATTEMPTS} attempts)"
    elif ((total % REALERT_EVERY_RUNS == 0)); then
      mins=$(((NOW - $(iso2epoch "$oldest_fail_ts")) / 60))
      tg "🔴 deadman: still unreachable, down ~${mins} min"
    fi
    echo "status: down"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
