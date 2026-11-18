---
name: kit-capture
description: Save a quick note, idea, or link into the vault Inbox with frontmatter, then offer to file it. Use when I say "capture this", "note this", or "save this idea".
---

# Capture

## Find the vault

Read `~/.claude/CLAUDE.md`. The line "My vault is at <path>" inside the vault-starter section gives the path. If it is missing, ask me.

## Steps

1. Get the text to capture from what I just said, or from what I point to. If it is unclear, ask once.
2. Get today's date with `date +%Y-%m-%d`.
3. Make a short title: three to six words, plain.
4. Write `<vault>/Inbox/<Title>.md`:

```
---
date: YYYY-MM-DD
tags: [inbox]
status: active
---

# <Title>

<what I said, cleaned up lightly, nothing added>
```

5. If a file with that name exists, add a number to the new name. Never overwrite.
6. Tell me the file was saved. Then offer one place to file it:
   - reference material goes to `Knowledge/`
   - work for a project goes to `Projects/<name>/`
   - a to-do goes into today's daily note
   - something I am done with goes to `Archives/`
7. Move it only if I say yes.

## Rules

- Keep my words. Do not invent facts or add advice.
- A link or clipping keeps its source URL in the note.
- One note per capture.
- Inbox items older than 7 days need a decision: file, archive, or delete. Mention it if you see old ones.
