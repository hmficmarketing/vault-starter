# {{NAME}}'s vault

This is {{NAME}}'s vault. It lives at {{VAULT_PATH}}. Read this file at the start of a session when you need context.

## Folders

| Folder | What goes here |
|--------|----------------|
| `Inbox/` | Raw notes, clippings, brain dumps. Not sorted yet. |
| `Projects/` | One folder per project, with finished work and project notes. |
| `Knowledge/` | Reference material: things worth keeping and looking up later. |
| `Daily Notes/` | One note per day, named `YYYY-MM-DD.md`. |
| `Templates/` | Note templates for daily notes and projects. |
| `Archives/` | Finished or inactive things. |

## Routing rule

- Raw notes go in `Inbox/`.
- Reference material goes in `Knowledge/`.
- Finished work goes in `Projects/`.
- Inbox items older than 7 days get processed: move them, archive them, or delete them.

## Note format

Every note starts with frontmatter:

```
---
date: YYYY-MM-DD
tags: []
status: active
---
```

- `date`: when the note was made.
- `tags`: short labels, for example `work`, `idea`, `reference`.
- `status`: `active`, `completed`, or `archived`.

Link notes to each other with wikilinks: `[[Note Name]]`, or `[[Note Name|shown text]]`.

## Session start

Before editing the vault in a new session, run `git pull --rebase` if the vault has no uncommitted changes. If it has uncommitted changes, do not pull. Tell {{NAME}} what is changed and ask what to do.

## Memory rules

- One fact per file.
- `MEMORY.md` is the index. It points to the files. It does not hold the facts.
- Update an existing memory instead of making a duplicate.
- Tag each plan line as decided ({{NAME}} said it) or proposed (Claude suggested it). Do not act on a proposal as if it were decided. Ask first.
