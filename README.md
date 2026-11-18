# Vault Starter Kit

A private kit that sets up a personal knowledge vault (Obsidian) and a safe Claude Code setup on someone's Mac. The person pastes one prompt into Claude Code, and their Claude does the rest: tools, vault, skills, and guards.

It is built for people who use the Claude desktop app and never touch the terminal.

## What it installs

- A vault folder (default `~/Vault`) with notes, templates, and a "How to use this vault" note.
- Six skills in `~/.claude/skills/`: kit-daily, kit-capture, kit-eod-flush, kit-handoff, kit-dream, kit-new-project.
- Two guard hooks in `~/.claude/hooks/`: one stops searches over the whole home folder or disk, one blocks reading folders on the person's private list. Both are registered in `~/.claude/settings.json`.
- A marked section in `~/.claude/CLAUDE.md` (optionally a tier block).
- An empty privacy list at `~/.claude/vault-starter/privacy-folders.txt`, filled in during setup from what the person says to keep private.
- Optionally a git backup of the vault to the person's own private GitHub repo.

Existing files are backed up first. If the person edited a file the kit manages, the kit keeps their version and writes the new one beside it as `.kit-new`.

## How to share it

1. Add the person as a collaborator on the private repo `hmficmarketing/vault-starter`, using their GitHub username.
2. Tell them to accept the GitHub invite email first. Until they do, the repo looks like it does not exist and the first clone fails.
3. Tell them to download Obsidian.
4. Send them `INSTALL-PROMPT.txt`. They paste it into Claude Code.

Their Claude follows `SETUP.md` from there.

## How to update it

1. Make your change.
2. Run `bash tests/run.sh`. Everything must pass.
3. Run your leak check from your own vault before every push. It must report 0 hits.
4. Push.

The person then tells their Claude: "update my vault starter kit". It pulls the kit and re-runs the installer with their saved answers. Their privacy list is kept.

## How to uninstall

The vault itself stays. Remove only the kit's parts:

1. In `~/.claude/CLAUDE.md`, delete the marked kit section (from the line `<!-- vault-starter:begin -->` to the line `<!-- vault-starter:end -->`).
2. Delete the `kit-` skill folders in `~/.claude/skills/`.
3. Delete `kit-home-scope-guard.sh` and `kit-privacy-guard.sh` from `~/.claude/hooks/`.
4. In `~/.claude/settings.json`, remove the two hook entries that point at those files.
5. Optionally delete `~/.claude/vault-starter/`.
