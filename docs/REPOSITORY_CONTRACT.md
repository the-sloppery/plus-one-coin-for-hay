# Repository contract: plus-one-coin-for-hay

- Organization: `the-sloppery`
- Repository class: `game`
- Agent context: [`the-sloppery/sloppery-dev`](https://github.com/the-sloppery/sloppery-dev); local pointer [`docs/AGENT_CONTEXT.md`](AGENT_CONTEXT.md).
- GitHub IaC: [`the-sloppery/iac-sloppery`](https://github.com/the-sloppery/iac-sloppery).
- Canonical templates: [`sloppery-dev/templates`](https://github.com/the-sloppery/sloppery-dev/tree/main/templates).
- Local issue forms: [`.github/ISSUE_TEMPLATE`](../.github/ISSUE_TEMPLATE).
- Local PR template: [`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md).
- CI: `.github/workflows/ci.yml`; the contract check is [`.github/workflows/contract.yml`](../.github/workflows/contract.yml).
- Runner: `[self-hosted, ww-linux]`. Labels must be registered to `the-sloppery`; Lobbi runner registrations and credentials are not reused.

## Ownership

This repository owns only the source and assets declared for `plus-one-coin-for-hay` in the
organization catalog. Organization settings belong in `iac-sloppery`; durable
agent context, handoffs, and evidence indexes belong in `sloppery-dev`.

## Change rules

Preserve existing source, dirty worktrees, and collaborator branches. State the
exact source head, checks actually run, evidence, and remaining UNKNOWNs in each
pull request. Do not publish, merge, rotate credentials, or change live
resources as a side effect of documentation or CI work.
