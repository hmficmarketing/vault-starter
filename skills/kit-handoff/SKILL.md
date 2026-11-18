---
name: kit-handoff
description: Write down what is done, what is next, and open questions so a new session can pick up the work. Use when I say "handoff", "wrap up this session", or before I stop for the day.
---

# Handoff

Goal: the next session starts with no memory of this one. Write what it needs.

## Where it goes

1. If I am inside an app folder with a `CLAUDE.md`, update that file's "Current state" section. Also update "Next" and add dated lines to "Decisions" when something was decided.
2. If the work is not an app, or no app `CLAUDE.md` exists, find the project note at `<vault>/Projects/<Name>/<Name>.md`. The vault path is in `~/.claude/CLAUDE.md`, in the line "My vault is at <path>". Update "Where it stands" and "Next steps".
3. If neither fits, ask me where it should go.

## What to write

- **Done:** what works now, in a few short lines. Say how you know. Name the command or check you ran.
- **Broken or half done:** what is not finished, and why.
- **Next:** the next steps, in order. The first one should be something a new session can start right away.
- **Open questions:** things I need to decide. One line each.
- **Where things are:** file names and commands that matter. Point to files. Do not copy their content.

## How

1. Read the current text of the section first. Edit it. Do not stack a second copy under the first.
2. Remove lines that are no longer true.
3. Use today's date from `date +%Y-%m-%d` for any dated line.
4. Show me the changes in plain words when done.

## Rules

- Never write keys, tokens, or passwords. Write the variable name and the .env file only.
- Do not write a diary of the session. Write the state of the work.
- Do not claim something works unless you checked it. If you did not check it, say "not checked".
- Keep it scannable: short lines, no long paragraphs.
