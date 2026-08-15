#!/usr/bin/env bash
# gha-deadman: probe TARGET_URL, keep up/down state in a repo Actions variable,
# send Telegram alerts on down, hourly re-alerts while down, and one recovery message.
set -euo pipefail

: "${TARGET_URL:?}" "${TELEGRAM_BOT_TOKEN:?}" "${TELEGRAM_CHAT_ID:?}" "${GH_TOKEN:?}" "${GH_REPO:?}"
STATE_VAR="${STATE_VAR:-DEADMAN_STATE}"
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

get_state() {
  "$GH" api "repos/$GH_REPO/actions/variables/$STATE_VAR" -q .value 2>/dev/null || echo ""
}

put_state() {
  local v="$1"
  if "$GH" api -X PATCH "repos/$GH_REPO/actions/variables/$STATE_VAR" -f value="$v" >/dev/null 2>&1; then
    return 0
  fi
  "$GH" api -X POST "repos/$GH_REPO/actions/variables" -f name="$STATE_VAR" -f value="$v" >/dev/null
}

main() {
  local prev state since last_alert mins
  prev="$(get_state)"
  [[ -z "$prev" ]] && prev='{}'
  state="$(jq -r '.state // "up"' <<<"$prev" 2>/dev/null || echo up)"
  since="$(jq -r '.since // 0' <<<"$prev" 2>/dev/null || echo 0)"
  last_alert="$(jq -r '.last_alert // 0' <<<"$prev" 2>/dev/null || echo 0)"

  if probe; then
    if [[ "$state" == "down" ]]; then
      mins=$(((NOW - since) / 60))
      tg "🟢 deadman: ${TARGET_URL} is reachable again (was down ~${mins} min)"
      put_state "{\"state\":\"up\",\"since\":$NOW,\"last_alert\":0}"
    fi
    echo "status: up"
  else
    if [[ "$state" != "down" ]]; then
      tg "🔴 deadman: ${TARGET_URL} is UNREACHABLE from GitHub (${PROBE_ATTEMPTS} attempts)"
      put_state "{\"state\":\"down\",\"since\":$NOW,\"last_alert\":$NOW}"
    elif ((NOW - last_alert >= REALERT_SECONDS)); then
      mins=$(((NOW - since) / 60))
      tg "🔴 deadman: still unreachable, down ~${mins} min"
      put_state "{\"state\":\"down\",\"since\":$since,\"last_alert\":$NOW}"
    fi
    echo "status: down"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
