---
name: kit-dream
description: Tidy the memory files. Merge duplicates, drop wrong or old ones, and keep MEMORY.md under 16 KB. Proposes changes first and applies them only on my yes. Use for "dream" or "clean up memory".
---

# Dream: memory cleanup

## Find the files

Read `~/.claude/CLAUDE.md`. The line "My vault is at <path>" gives the vault. Memory is in `<vault>/.claude/memory/`. `MEMORY.md` there is the index. The other files each hold one fact.

If the folder is missing, say so and stop.

## Step 1: look

1. Run `wc -c` on `MEMORY.md`. The limit is 16 KB (16384 bytes).
2. List every memory file with its size.
3. Read `MEMORY.md`, then read each memory file.

## Step 2: find problems

- **Duplicates:** two files that say the same thing. Merge them.
- **Wrong or old:** a fact that is no longer true, or that conflicts with something newer. Check against the vault or the app files when you can. Drop it or fix it.
- **Many facts in one file:** split it, one fact per file.
- **Broken links:** an index line that points to a file that does not exist, or a file the index does not list.
- **Facts in the index:** `MEMORY.md` should only point to files. Move facts out into a file.
- **Proposals acting as decisions:** a note that records an idea I did not approve. Tag it "proposed".
- **Things not worth saving:** anything you can get by reading the code or the vault, one-off task details, and secrets. Secrets must never be in memory. Flag them at once.

## Step 3: propose

Show a numbered list. For each item give:
- what you would do (merge, drop, fix, split, move)
- which files
- why, in one line

Show the byte count now and the count after. Then ask: "Apply these?" I can say yes to all, pick numbers, or say no.

## Step 4: apply

Only after my yes, and only the items I approved. Then rerun `wc -c` on `MEMORY.md` and show it.

## Rules

- Never change anything before my yes.
- Never delete a memory unless I approved that item. When in doubt, mark it for my review.
- Keep each memory's date and its decided or proposed tag.
- If `MEMORY.md` is still over 16 KB, say what else could go. Do not trim past what I approved.
