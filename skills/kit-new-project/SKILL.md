---
name: kit-new-project
description: Set up a new app or project. Makes its CLAUDE.md from the kit template, a project note in the vault, and a row in the Code folder CLAUDE.md. Use for "new project" or "start a new app".
---

# New project

## Step 1: ask

Ask me, one at a time:
1. The app name.
2. The folder for it. Suggest `~/Code/<app-name>` as the default.
3. One sentence: what is it and who is it for?

Do not go on until you have the name and folder.

## Step 2: find the vault

Read `~/.claude/CLAUDE.md`. The line "My vault is at <path>" gives the vault path. If it is missing, ask me.

## Step 3: check first

- If the folder already has a `CLAUDE.md`, stop and ask. Never overwrite it.
- If `<vault>/Projects/<App>/<App>.md` exists, stop and ask.
- Create the app folder if it does not exist.

## Step 4: make the files

1. **App file.** Copy `~/.claude/vault-starter/template/app/CLAUDE.md` to `<folder>/CLAUDE.md`. Put the app name in the title and my sentence under "What this is". Leave the other sections for later.
2. **Vault note.** Copy `<vault>/Templates/Project.md` to `<vault>/Projects/<App>/<App>.md`. Replace `{{date}}` with today's date (`date +%Y-%m-%d`) and `{{title}}` with the app name. Under "Goal", write my sentence. Add a line: `App folder: <folder>`, and say its `CLAUDE.md` is the source of truth for the app.
3. **Code folder row.** Open `~/Code/CLAUDE.md`. Add a row for the app under its apps list: name, folder, one-line purpose. If the file or list is missing, tell me and skip this step.

## Step 5: report

Say what was created, with the three paths. Then ask what the first step is, and put the answer under "Next" in the app's `CLAUDE.md`.

## Rules

- Never overwrite an existing file.
- No secrets in any of these files.
- Do not run `git init` or create a remote unless I ask.
