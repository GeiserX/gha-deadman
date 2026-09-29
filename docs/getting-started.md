# Getting started

gha-deadman needs a public GitHub repository (for free Actions minutes) and a Telegram bot. Nothing runs on your own machines.

1. Fork or copy this repository (public, so the Actions minutes are free).
2. Create a Telegram bot with [@BotFather](https://t.me/BotFather), and get
   your chat id (send the bot a message, then check
   `https://api.telegram.org/bot<TOKEN>/getUpdates`).
3. Add three repository secrets (Settings > Secrets and variables > Actions):

   | Secret | Value |
   |---|---|
   | `TARGET_URL` | The URL to probe. Any HTTP 2xx/3xx counts as alive; pick a dynamic, uncacheable endpoint so a CDN can't answer for a dead origin. |
   | `TELEGRAM_BOT_TOKEN` | The bot token from BotFather. |
   | `TELEGRAM_CHAT_ID` | Your numeric chat id. |

4. Run the `deadman` workflow once by hand (Actions > deadman > Run workflow)
   to confirm the happy path, and once with `TARGET_URL` pointed at something
   dead to confirm the alert actually fires. An alert you have never seen fire
   is not an alert.

Pick a `TARGET_URL` that is only healthy while the thing you care about is healthy: a status page served by your monitoring server is a good choice, because it goes down when the monitoring does.

The thresholds are in [Configuration](configuration.md); what you receive and when is in [Usage](usage.md).
