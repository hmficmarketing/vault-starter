---
name: kit-eod-flush
description: End-of-session vault cleanup. Check what changed in the vault, group it, propose commits, commit on my yes, then pull and push on a second yes. Use for "flush the vault" or "end of day".
---

# End-of-day flush

## Find the vault

Read `~/.claude/CLAUDE.md`. The line "My vault is at <path>" gives the path. Run every command inside that folder. If the vault is not a git repo, say so and stop.

## Steps

### 1. Look

Run `git status -sb` and `git diff --stat`. If nothing changed, say "Vault is clean" and stop.

### 2. Group

Sort the changed files into groups by folder or topic. Example: daily notes, one project, memory, inbox. Each group becomes one commit.

### 3. Check for secrets

Look at the file list for `.env`, key files, or anything named like a password or token. If you see one, do not stage it. Tell me and ask what to do.

### 4. Propose

Show a short list. For each group, give:
- the files, in a few words
- the commit text you would use, in the form `type: short summary`

Then ask: "Commit these?" Wait for my answer. I may say yes, skip a group, or change the text.

### 5. Commit

On a yes, run `git add` with the exact files for each group, then `git commit`. Never use `git add -A`. Show the result of `git log --oneline` for the new commits.

### 6. Pull and push

Ask: "Pull and push now?" On a yes:

1. Run `git pull --rebase`.
2. If it conflicts, stop. Show me the conflicting files. Do not guess a fix.
3. Run `git push`. Show the output.

If I say no, stop. The commits stay local.

## Rules

- Never push without a fresh yes in this run.
- Never force push. Never rewrite history.
- Never delete files to make the status clean.
- If there are more than 15 changed files, say so and suggest smaller commits.
