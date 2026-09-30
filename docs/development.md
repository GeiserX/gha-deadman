# Development

All the logic is in `scripts/check.sh`. The `deadman` workflow runs it; `keepalive` only calls the GitHub API.

## Tests

```bash
shellcheck scripts/*.sh
./scripts/test.sh
```

`scripts/test.sh` runs `check.sh` against fake `curl` and `gh` scripts, passed in through the `CURL` and `GH` variables, with a fixed clock (`NOW_OVERRIDE`). Each case sets the probe result (`MOCK_PROBE_RC`) and the run history (`MOCK_HIST`), then checks the exit code and which Telegram messages were sent. The eight cases cover a first failure, a recovery, steady up, a quiet first hour of outage, the hourly reminder, no repeat inside one hour, a long scheduler gap, and a first run that finds the URL up. A last case expects the wrong exit code on purpose and must fail, which proves the harness can go red. A good run ends with `ALL TESTS PASSED`; the `FAIL [control]` line printed just before it is that last case failing, as it should. You need `bash` and `jq`.

The `ci` workflow runs both commands on every pull request and on every push to `main`.

## Rules for changes

- `check.sh` uses `curl`, `jq` and `gh` only, all preinstalled on `ubuntu-latest`. No third-party actions.
- Every change to the state machine gets a matching case in `scripts/test.sh`.
- State stays in the run history. The workflow's `GITHUB_TOKEN` cannot write repository Actions variables (HTTP 403, `Resource not accessible by integration`, even with `actions: write`), which is why the design is stateless.
- `keepalive` stays a separate workflow, so its green runs never enter the probe's run history.
- The reminder interval stays measured in elapsed outage time, never in a number of runs: GitHub's scheduler does not keep the cron's pace.
- The three secrets are never committed, logged or echoed.

## The docs site

The site is built with [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) from `docs/` and `mkdocs.yml`:

```bash
pip install -r docs/requirements-docs.txt
mkdocs build --strict
```

The `Docs` workflow runs the same strict build on every pull request and deploys `main` to GitHub Pages. A broken link, a missing page or a page left out of the nav fails the build.

Commits follow [Conventional Commits](https://www.conventionalcommits.org/). The code is [GPL-3.0-or-later](https://github.com/GeiserX/gha-deadman/blob/main/LICENSE).
