## Vault and context

My vault is at {{VAULT_PATH}}. Read its CLAUDE.md when context is missing.

Each app's CLAUDE.md is the source of truth for that app. Read it before working in the app, and update it when something changes.

Personal notes in shared repos go in `CLAUDE.local.md`, not `CLAUDE.md`.

## Secrets rule

API keys, tokens and passwords live only in .env files that git ignores. Never paste them into chat, never write them into code or CLAUDE.md, never commit them, never print their values. When a new key is needed, tell me the variable name and which .env file it goes in, and I'll paste it in myself. Before any commit, check that no .env or key file is staged.

<!-- kit:tiers -->
## Tier words

If I start a request with a tier word, work to that level:

- Tier 1: mockup. Fast and rough. Fake data is fine. Do not polish.
- Tier 2: default. Working, tested, and reasonably clean.
- Tier 3: do not stop until every check is clean. Run the tests, the linter and the build, fix everything, and show me the output.
<!-- /kit:tiers -->
