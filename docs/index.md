---
hide:
  - navigation
---

# gha-deadman { .gd-visually-hidden }

<p align="center">
  <img src="images/banner.svg" alt="gha-deadman: a dead-man's switch on free GitHub Actions" width="100%">
</p>

<p align="center">
  <a href="https://github.com/GeiserX/gha-deadman/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/GeiserX/gha-deadman/ci.yml?branch=main&style=flat-square&label=ci"></a>
  <a href="https://github.com/GeiserX/gha-deadman/actions/workflows/deadman.yml"><img alt="The author's own switch, live" src="https://img.shields.io/github/actions/workflow/status/GeiserX/gha-deadman/deadman.yml?branch=main&style=flat-square&label=deadman"></a>
  <a href="https://github.com/GeiserX/gha-deadman/stargazers"><img alt="GitHub Stars" src="https://img.shields.io/github/stars/GeiserX/gha-deadman?style=flat-square&logo=github"></a>
  <a href="https://github.com/GeiserX/gha-deadman/blob/main/LICENSE"><img alt="License: GPL-3.0-or-later" src="https://img.shields.io/github/license/GeiserX/gha-deadman?style=flat-square"></a>
</p>

---

**gha-deadman** messages you on Telegram when a URL stops answering, and it checks from GitHub's runners, outside your network. Your monitoring server tells you when something breaks, but nothing tells you when the monitoring server itself breaks. Point gha-deadman at a page that is only healthy while your monitoring is healthy, and that gap is closed. It is a fork of this repository, a Telegram bot and three repository secrets: no server, no CLI, nothing to install, and no cost on a public repository. Start with [Getting started](getting-started.md), then [Usage](usage.md).

<div class="grid cards" markdown>

-   :material-source-fork: **[Getting started](getting-started.md)**

    ---

    Fork the repository, create the bot, add the three secrets, and make the alert fire once on purpose.

-   :material-message-alert-outline: **[The messages](usage.md#the-messages)**

    ---

    What you receive when the URL goes down, while it stays down, and when it answers again.

-   :material-history: **[The outage log](usage.md#the-run-history-is-the-outage-log)**

    ---

    The workflow's run list is the record of every outage; nothing else is kept.

-   :material-tune-variant: **[Configuration](configuration.md)**

    ---

    Every threshold, its default, and where the schedule lives.

</div>

## What you receive

Three messages, sent straight to the Telegram Bot API by `scripts/check.sh`. With an invented target they read:

```text
🔴 deadman: https://status.example.com/health is UNREACHABLE from GitHub (2 attempts)
🔴 deadman: still unreachable, down ~214 min
🟢 deadman: https://status.example.com/health is reachable again (was down ~431 min)
```

One when the URL goes down, a reminder on the first run after each hour of outage, and one when it answers again, with how long it was down. While the URL is up, nothing is sent. [Usage](usage.md) has the details.

## How fast it notices

The workflow asks for a run every 10 minutes; GitHub decides when it actually runs. On this repository, from 15 to 25 August 2026 the median gap between scheduled runs was 30 minutes. From 29 August to 30 September 2026 it was 3 hours 32 minutes, and the longest gap was 8 hours 20 minutes (216 runs). So gha-deadman tells you that your monitoring host has been down for a while. It does not catch an outage that ends before the next run. [How it works](how-it-works.md#how-fast-it-notices) has the numbers and why a tighter cron does not help.

## How it runs

- `.github/workflows/deadman.yml` runs `scripts/check.sh` on a GitHub-hosted `ubuntu-latest` runner, which is free on a public repository. The script needs only `curl`, `jq` and `gh`, all already on the runner; there are no third-party actions.
- Each run makes up to two attempts 25 seconds apart, 20 seconds each. Any HTTP status below 400 counts as up.
- Nothing is stored. The workflow's own run history says whether the URL was already down and since when, as [How it works](how-it-works.md#the-pieces) explains.
- A weekly `keepalive.yml` re-enables both workflows, so GitHub does not switch the schedule off after 60 days without activity in the repository.

## What it does not do

- It is not an uptime monitor: it sees the state of the URL only at the moment a run happens.
- It watches one URL per repository. A second URL needs a second copy.
- It sends to Telegram only.
- It checks the HTTP status only, not the body, and does not follow redirects. A CDN that answers for a dead origin looks up, so pick an uncacheable endpoint ([Getting started](getting-started.md) says which).

## Privacy

- The URL, the bot token and the chat id are repository secrets. They are never committed, and GitHub masks each of them in the run logs.
- The run history of a public repository is public. Anyone can see when your target was down: a streak of red `deadman` runs.
- A failed probe never prints the URL or its host. GitHub masks the whole URL but not the host inside it, and `curl`'s own error line names the host, so the script drops that line and prints only the `curl` exit code and the HTTP status.

## Getting help

- Something does not work: read [Troubleshooting](troubleshooting.md), then open an [issue](https://github.com/GeiserX/gha-deadman/issues) with what its "Reporting a bug" section lists.
- A security problem: follow the [security policy](https://github.com/GeiserX/gha-deadman/blob/main/SECURITY.md), never a public issue.
- Changing the script or the docs: [Development](development.md).

## License

gha-deadman is released under the [GPL-3.0-or-later](https://github.com/GeiserX/gha-deadman/blob/main/LICENSE) license.
