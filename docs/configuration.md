# Configuration

The three secrets (`TARGET_URL`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`) are in [Getting started](getting-started.md). Everything else is an environment variable in `scripts/check.sh` (override it in the workflow if needed):

| Variable | Default | Meaning |
|---|---|---|
| `PROBE_ATTEMPTS` | `2` | Failed attempts required to call it down |
| `PROBE_RETRY_DELAY` | `25` | Seconds between attempts |
| `PROBE_TIMEOUT` | `20` | Per-attempt timeout in seconds |
| `REALERT_SECONDS` | `3600` | Reminder interval while down, in elapsed outage time |
| `WORKFLOW_FILE` | `deadman.yml` | Workflow whose run history is read as state |

The probe schedule is the `*/10` cron in `.github/workflows/deadman.yml`. Tightening it does not reliably help: see [How it works](how-it-works.md#how-fast-it-notices).
