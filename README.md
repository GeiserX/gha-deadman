<p align="center">
  <img src="docs/images/banner.svg" alt="gha-deadman" width="900">
</p>

# gha-deadman

[![ci](https://github.com/GeiserX/gha-deadman/actions/workflows/ci.yml/badge.svg)](https://github.com/GeiserX/gha-deadman/actions/workflows/ci.yml)
[![deadman](https://github.com/GeiserX/gha-deadman/actions/workflows/deadman.yml/badge.svg)](https://github.com/GeiserX/gha-deadman/actions/workflows/deadman.yml)
[![License](https://img.shields.io/github/license/GeiserX/gha-deadman)](LICENSE)

A dead-man's switch that runs entirely on free GitHub Actions, with no CLI and nothing to install. It probes a URL every 10 minutes from GitHub's infrastructure, outside your network and your monitoring stack, and messages you on Telegram when the URL stops answering, hourly while it stays down, and once when it recovers. Point it at any URL that is only healthy while your monitoring is healthy, and the watcher is watched, with no infrastructure and no cost.

## Features

- Probes any URL every 10 minutes from GitHub-hosted runners, free on a public repository.
- Two attempts 25 s apart before calling it down, so one network blip does not page you.
- One Telegram message when the URL goes down, a reminder for each hour of outage (sent by the first run after the hour, as GitHub delays scheduled runs), one on recovery with the outage duration.
- Stateless: the workflow's own run history is the state and doubles as the outage log.
- No third-party actions; `curl`, `jq` and `gh` only.
- A weekly keepalive workflow stops GitHub from disabling the schedule after 60 days of inactivity.
- Every threshold is an environment variable in `scripts/check.sh`.

## Quick start

1. Fork or copy this repository (public, so the Actions minutes are free).
2. Create a Telegram bot with [@BotFather](https://t.me/BotFather) and get your chat id.
3. Add the repository secrets `TARGET_URL`, `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (Settings > Secrets and variables > Actions).
4. Run the `deadman` workflow once by hand, and once with `TARGET_URL` pointed at something dead, to see both paths.

The details of each step are in [Getting started](docs/getting-started.md).

## Documentation

- [Getting started](docs/getting-started.md): the bot, the secrets, and the test that proves the alert fires
- [Configuration](docs/configuration.md): the probe and re-alert thresholds
- [Usage](docs/usage.md): the three Telegram messages and the run history as an outage log
- [How it works](docs/how-it-works.md): the stateless design, the keepalive workflow, and how fast it really notices

## License

[GPL-3.0-or-later](LICENSE)
