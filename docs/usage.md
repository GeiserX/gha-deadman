# Usage

Once the secrets are in place, there is nothing to run. Steady state sends nothing; you hear from gha-deadman only when the target changes state or stays down.

## The messages

| When | Telegram message |
|---|---|
| The URL goes down | `🔴 deadman: <url> is UNREACHABLE from GitHub (2 attempts)` |
| Every `REALERT_SECONDS` (one hour) while it stays down | `🔴 deadman: still unreachable, down ~<minutes> min` |
| The URL answers again | `🟢 deadman: <url> is reachable again (was down ~<minutes> min)` |

## The run history is the outage log

A run that finds the target down fails (red); a run that finds it up passes (green). The `deadman` workflow's run list under Actions is therefore the record of every outage: a streak of red runs is one outage, from its first red run to the next green one. No other state is kept anywhere.
