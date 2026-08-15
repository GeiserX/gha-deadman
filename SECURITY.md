# Security Policy

## Supported Versions

Only the latest commit on `main` is supported.

## Reporting a Vulnerability

Please report vulnerabilities privately:

1. Go to https://github.com/GeiserX/gha-deadman/security/advisories
2. Click "Report a vulnerability"
3. Include reproduction steps and impact

You will get an initial response within a few days. Please do not open public
issues for security reports.

## Scope notes

- The workflow runs with a `GITHUB_TOKEN` restricted to `actions: write` and
  `contents: read` — it can toggle workflows and write Actions variables in
  its own repository, nothing else.
- `TARGET_URL`, `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` live only in
  repository Actions secrets and are masked in logs. Anything that could leak
  them (echoing, uploading logs elsewhere) is a valid report.
- The scripts intentionally use only `curl`, `jq` and `gh` — adding
  third-party actions or dependencies expands the supply-chain surface and
  needs a strong reason.
