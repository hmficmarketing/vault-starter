---
name: kit-daily
description: Create or open today's daily note, then run a morning plan or an evening wrap-up. Use when I say "daily", "start my day", "plan my day", or "wrap up my day".
---

# Daily note

## Find the vault

Read `~/.claude/CLAUDE.md`. The line "My vault is at <path>" inside the vault-starter section gives the vault path. Use that path. If the line is missing, ask me where the vault is.

## Step 1: get today's date

Run `date +%Y-%m-%d` and `date +%A` first. The system clock is the only source of truth. Do not trust memory or older notes for the date.

## Step 2: create or open today's note

The note is `<vault>/Daily Notes/YYYY-MM-DD.md`.

- If it exists, open it and read it. Do not overwrite it.
- If it does not exist, copy `<vault>/Templates/Daily.md` and replace `{{date}}` with today's date.

Then look at yesterday's note, if there is one. Pull any unfinished items from its "Tomorrow" section.

## Morning

1. Show me yesterday's carry-overs, one line each.
2. Ask: "What matters most today?" Wait for my answer.
3. Write my answer into "Top 3 today". Keep it to three items. If I give more, ask which three.
4. Say the plan back in two or three short lines.

## Evening

1. Read today's note.
2. Ask what got done. Write it under "Done".
3. Ask what did not get done. For each item, ask: carry it to tomorrow, or drop it?
4. Write the carried items under "Tomorrow".
5. Ask for one thing that went well and one thing to change. Add them under "Notes".

## Rules

- Never delete what I wrote in a note. Add to it.
- Keep notes short. One line per item.
- Use wikilinks for projects: `[[Project Name]]`.
- Talk plain. Short sentences.
