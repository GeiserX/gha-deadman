# How it works

You run a monitoring server (Uptime Kuma, Prometheus, whatever) that alerts you when things break. But who alerts you when the monitoring server breaks? gha-deadman runs outside your network, on GitHub's runners, and watches a URL that is only healthy while your watcher is healthy.

## The pieces

- `.github/workflows/deadman.yml` runs on a `*/10` cron on GitHub-hosted
  runners (free and unlimited on public repositories).
- `scripts/check.sh` probes `TARGET_URL` (2 attempts, 25 s apart, so a single
  network blip doesn't page you) and talks to the Telegram Bot API directly:
  no third-party actions, no dependencies beyond `curl`, `jq` and `gh`.
- **Stateless by design**: the workflow's own run history is the state. A
  failing probe exits non-zero, so the previous run's conclusion says whether
  the target was already down, the streak of consecutive red runs drives the
  re-alert cadence, and the oldest red run's timestamp gives the outage
  duration. Nothing is stored anywhere, and the run history doubles as an
  outage log. (This also sidesteps a real limitation: the workflow
  `GITHUB_TOKEN` cannot write repository Actions variables.)
- Alert policy: one message on the up-to-down transition, a reminder every hour
  while down, one message on recovery with the outage duration. Steady state
  sends nothing.
- A separate weekly `keepalive.yml` re-enables both workflows through the GitHub
  API so the schedules survive GitHub's 60-day inactivity auto-disable. It is
  separate on purpose, so its green runs never pollute the probe's history.

## How fast it notices

Much slower than the cron suggests. GitHub's scheduler is explicitly
best-effort: it delays and drops scheduled runs, and nothing in the workflow can
make it keep a `*/10` pace. The scheduled runs of this repository:

| Period | Scheduled runs | Median gap | 90% of gaps under | Longest gap |
|---|---|---|---|---|
| 15 to 25 August 2026 | 437 | 30 min | 51 min | 1 h 50 min |
| 29 August to 30 September 2026 | 216 | 3 h 32 min | 5 h 25 min | 8 h 20 min |

So expect to hear about an outage within a few hours, and in the worst gap
measured, more than eight. That is fine for "my monitoring host died" and
useless for "my API had a 90-second blip": this is a dead-man's switch, not an
uptime SLA monitor. Tightening the cron does not help; the throttling is on
GitHub's side.

Because the cadence is unreliable, the reminder interval is measured in elapsed
outage time (`REALERT_SECONDS`), not in number of runs, so a reminder never
comes more than once an hour however often GitHub runs the workflow. When runs
are more than an hour apart, as they have been since late August, every run
during an outage sends one.
