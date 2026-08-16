#!/usr/bin/env bash
# gha-deadman: probe TARGET_URL and alert on Telegram. Stateless by design —
# the workflow's own run history IS the state: the previous completed run's
# conclusion says whether we were up or down, the streak of consecutive
# failures drives hourly re-alerts, and the oldest failure's timestamp gives
# the outage duration. Nothing is stored anywhere.
set -euo pipefail

: "${TARGET_URL:?}" "${TELEGRAM_BOT_TOKEN:?}" "${TELEGRAM_CHAT_ID:?}" "${GH_TOKEN:?}" "${GH_REPO:?}"
WORKFLOW_FILE="${WORKFLOW_FILE:-deadman.yml}"
# Reminder cadence is measured in elapsed outage time, not in runs: GitHub's
# scheduler is best-effort (measured median ~31 min for a */10 cron, worst
# case ~80), so counting runs would make "hourly" mean anything at all.
REALERT_SECONDS="${REALERT_SECONDS:-3600}"
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
  local prev="" prev_ts="" oldest_fail_ts="" counting=1 concl ts
  local down_since mins bucket_now bucket_prev
  while IFS=' ' read -r concl ts; do
    [[ -z "$concl" ]] && continue
    if [[ -z "$prev" ]]; then
      prev="$concl"
      prev_ts="$ts"
    fi
    if ((counting)); then
      if [[ "$concl" == "failure" ]]; then
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
    if [[ "$prev" != "failure" ]]; then
      tg "🔴 deadman: ${TARGET_URL} is UNREACHABLE from GitHub (${PROBE_ATTEMPTS} attempts)"
    else
      # Remind once per REALERT_SECONDS of outage: alert when this run crosses
      # into a later bucket than the previous run occupied.
      down_since="$(iso2epoch "$oldest_fail_ts")"
      bucket_now=$(((NOW - down_since) / REALERT_SECONDS))
      bucket_prev=$((($(iso2epoch "$prev_ts") - down_since) / REALERT_SECONDS))
      if ((bucket_now > bucket_prev && bucket_now > 0)); then
        mins=$(((NOW - down_since) / 60))
        tg "🔴 deadman: still unreachable, down ~${mins} min"
      fi
    fi
    echo "status: down"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
