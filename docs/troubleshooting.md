# Troubleshooting

Every answer starts in the same place: Actions > deadman > the run > the `Probe target` step. The script prints `status: up` or `status: down`, `telegram: sent` after each message Telegram accepted, and `curl`'s error line when a Telegram request fails. A failed probe prints `probe: attempt 1/2 failed (curl exit 6, HTTP 000)` instead of `curl`'s error line, because that line names the target's host. The common exit codes: 6, the name does not resolve; 7, the connection was refused; 28, it timed out; 22, the server answered with the HTTP status shown.

## The test alert never arrived

- The log has no `telegram: sent`, and a line such as `curl: (22) The requested URL returned error: 401`: the bot token is wrong.
- `error: 400`: the chat id is wrong, or you have not sent the bot a message yet. A bot cannot start a chat; send it any message, then read the chat id again as [Getting started](getting-started.md) shows.
- `error: 403`: you blocked the bot in Telegram. Unblock it.

While the URL is up, the script never calls Telegram, so a wrong token or chat id stays hidden until the first outage. That is why Getting started has you point `TARGET_URL` at something dead once. A message that fails to send also fails the run. A recovery message that fails is sent again by the next run; a first alert that fails is not, and the next message you get is the hourly reminder.

## A run failed with "parameter null or not set"

`./scripts/check.sh: line 9: TARGET_URL: parameter null or not set` (or the same for `TELEGRAM_BOT_TOKEN` or `TELEGRAM_CHAT_ID`) means that repository secret is missing or empty. Add it under Settings > Secrets and variables > Actions.

That red run counts as an outage in the run history, so the first good run after you add the secret sends a "reachable again" message for an outage that never happened. Expect it once.

## Nothing runs in my fork

GitHub does not run the workflows of a forked repository until you enable them in the fork's Actions tab. Enable them, then run `deadman` once by hand (Actions > deadman > Run workflow).

## The alert came hours late

GitHub runs scheduled workflows when it can, not when the cron asks. On this repository the median gap between runs has been over three hours since late August 2026, against a 10-minute cron. Nothing in the repository can change that; [How it works](how-it-works.md#how-fast-it-notices) has the measurements.

## The workflow stopped running

GitHub disables a scheduled workflow after 60 days without activity in a public repository. The weekly `keepalive` workflow re-enables both workflows to prevent that. If the Actions page says a workflow is disabled, open it and choose Enable workflow, and check that `keepalive` is enabled too.

## It says up while my service is down

Any HTTP status below 400 counts as up, and redirects are not followed, so a 301 is up. A CDN or cache that still answers for a dead origin, or a redirect in front of the service, hides the outage. Point `TARGET_URL` at an endpoint that only the live service can answer, as [Getting started](getting-started.md) recommends.

## Reporting a bug

Open an [issue](https://github.com/GeiserX/gha-deadman/issues) with:

- the link to the run, and the `Probe target` log lines around the problem;
- the Telegram message you received, if any, and the one you expected;
- whether your copy is a fork or a copy, and any threshold you changed in [Configuration](configuration.md).

For a security problem, follow the [security policy](https://github.com/GeiserX/gha-deadman/blob/main/SECURITY.md) instead.
