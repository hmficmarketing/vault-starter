# Vault Starter Kit: setup instructions

These instructions are for Claude. The person you are helping is on a Mac, uses the Claude desktop app, and does not use the terminal. You do all the work. Speak to them in plain words, short sentences, one question at a time. Say what you found, what you are about to do, and why.

## Rules while you set this up

- Only look in `~/.claude`, `~/Code` (or the folder where the person says their apps live), and the vault folder. Never search the whole home folder or the whole disk. Do not run `mdfind`, a recursive grep over the home folder, or a recursive find over it.
- If you cannot find something in a known place, ask the person. Do not hunt for it.
- Ask before anything that touches GitHub: creating a repo, pushing, or downloading an installer.
- Never print secrets, tokens, or passwords.
- Back up before touching an existing file. The installer does this for you. If you edit anything by hand, copy it to `<name>.bak` first.
- Never edit around an installer refusal. See step 5.
- Use absolute paths in every command that has quotes, `--vault`, `--privacy`, `--source` and `git -C`. First run `echo $HOME` and use the full result (it looks like `/Users/<them>`). The `~` shortcut does not expand inside quotes, so it silently breaks things. Below, `<home>` means that full path.
- First run or update? If answers.json already exists in `<home>/.claude/vault-starter/`, this is an update. Go straight to step 9. Do not do steps 1 to 8 again.

The only clicks the person should need are: downloading Obsidian (they may have done this already), the Xcode tools "Install" button if it appears, the GitHub installer window if you had to download it (Continue, Install, Mac password), and the GitHub sign-in in the browser.

## 1. Check the tools

Run each check. Fix only what fails.

- git: run `git --version`. If it fails, run `xcode-select --install` and tell the person: "A box will pop up. Click Install and wait for it to finish. Tell me when it is done." Then check again.
- gh: run `gh --version`. If it fails:
  - If `brew --version` works, run `brew install gh`.
  - Otherwise, tell the person you need to download the GitHub tool from GitHub's official releases (cli/cli) and get their OK first. Then run `curl -s https://api.github.com/repos/cli/cli/releases/latest`, pick the asset whose name ends in `_macOS_universal.pkg`, and download it into a fresh temp folder (`mktemp -d`). Run `open "<pkg path>"` and tell the person: "An installer window opens. Click Continue, then Install, and enter your Mac password." Never use sudo. When it finishes, check `gh --version`, then delete the temp folder.
- Sign-in: run `gh auth status`. If it fails, run `gh auth login --web --git-protocol https` in the background (so the call does not block). Read its output as it streams. It prints a one-time code. Show it to the person in plain words: "A browser page will open. Type this code: XXXX-XXXX, then click Authorize." Wait until `gh auth status` succeeds. Then run `gh auth setup-git`, so plain git pulls on the private repo work.

## 2. Get the kit

If `<home>/Code/vault-starter` does not exist, run `gh repo clone hmficmarketing/vault-starter <home>/Code/vault-starter` (create `<home>/Code` first if needed). If it exists, run `git -C <home>/Code/vault-starter pull`.

## 3. Read what is already there

Look at these, and only these:

- `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.claude/agents/`, and the names of the folders in `~/.claude/skills/`.
- A listing of `~/Code`, or ask the person where their apps live.

Tell the person what you found in 3 short lines. Example: "You have a few skills already, no settings changes, and 4 apps in Code. I will not touch any of it without a backup."

## 4. Ask 5 questions

Ask one at a time. Wait for each answer.

1. Where should the vault go? Default `<home>/Vault`. Store it as a full absolute path.
2. What is your name?
3. What apps or projects do you have so far? A short list is fine. Pass it as `--apps "a, b"`.
4. Do you want the vault backed up to GitHub? Yes or no.
5. "What personal stuff should Claude never open? For example your texts, photos, email, or anything else."

For question 5, do not search. Use what you already know about where macOS keeps the data for each thing they named. Then confirm each candidate with a direct existence check on that exact path, for example `ls -d "<absolute path>"`. Use full absolute paths, never `~`. Only keep paths that exist. If you are not sure where something lives, ask the person. Show them the final list in plain words and get a yes. If they name nothing, the list stays empty. You will pass the list as `--privacy "path1;path2"`. The installer saves it to `~/.claude/vault-starter/privacy-folders.txt`, and the privacy guard blocks Claude from reading those folders.

## 5. Run the installer

Run:

```
bash "<home>/Code/vault-starter/scripts/install.sh" --vault "<vault>" --name "<name>" --apps "<apps>" --privacy "<p1;p2>"
```

All paths in it are absolute.

- Leave out `--privacy` if the list is empty.
- Add `--no-tiers` if `~/.claude/CLAUDE.md` already mentions "tier 1" (any capitalization). It means they already have a tier system, and the kit should not add its own.
- Add `--git` if the person wants the vault to be a git repo (always add it if they said yes to backup in question 4).
- The last line it prints is `vault-starter: installed`. If you do not see it, it did not finish.
- If it says "You changed X, so I kept your version. The new one is at X.kit-new.", pass that on in plain words: the kit left their edited file alone and put the new version beside it.
- If the installer exits with an error, show the person its message in plain words. Explain what it means (for example a damaged marker in CLAUDE.md, a settings.json that is not valid, or a memory folder linked somewhere else). Offer to fix the cause, and wait for their OK before changing anything. Never edit around the refusal silently.

## 6. Back up to GitHub (only if they said yes)

Show the person this command and what it does: it creates a private repo called `vault` under their GitHub account, and uploads the vault there. Get a yes, then run:

```
gh repo create <their-login>/vault --private --source "<vault>" --push
```

Get their login from `gh api user --jq .login`.

## 7. Check it works and show proof

Show the person the real output of each, not a summary.

- Run `bash <home>/Code/vault-starter/tests/run.sh`. It must pass. It runs in a throwaway folder and does not touch their files.
- Prove the search guard works without running a risky search. Pipe a fake tool call into the installed hook and read the exit code:

  ```
  echo '{"tool_name":"Bash","tool_input":{"command":"find ~ -name x"}}' | bash <home>/.claude/hooks/kit-home-scope-guard.sh; echo "exit $?"
  ```

  Expect `exit 2`.
- If the privacy list is not empty, do the same for the privacy hook with a Read of a file inside the first privacy folder:

  ```
  echo '{"tool_name":"Read","tool_input":{"file_path":"<first privacy folder>/x"}}' | bash <home>/.claude/hooks/kit-privacy-guard.sh; echo "exit $?"
  ```

  Expect `exit 2`. (This only checks the path. It does not open anything.)
- List the skills: `ls ~/.claude/skills | grep '^kit-'`. You should see 6: kit-daily, kit-capture, kit-eod-flush, kit-handoff, kit-dream, kit-new-project.
- `git -C <vault> log -1` shows a commit (when `--git` was used).
- `git -C "<vault>" remote -v` shows the remote (when backup is on).

If any check fails, say so plainly and show the output. Do not call setup done.

Then tell the person: "Start a new Claude Code session. The guards and the kit skills only load in a new session."

## 8. Tell them how to open it

Tell the person: "Open Obsidian. Choose Open folder as vault. Pick the vault folder. Then read the note called How to use this vault."

## 9. Updates

When the person says "update my vault starter kit":

1. Run `git -C <home>/Code/vault-starter pull`.
2. Read `<home>/.claude/vault-starter/answers.json`. Keys: `name`, `vault`, `apps` (a list, join it with ", " for `--apps`), `privacy`, `no_tiers` and `git` (true or false).
3. Re-run the installer with those values and no `--privacy` flag, so their privacy list is kept. Add `--no-tiers` if `no_tiers` is true and `--git` if `git` is true. Do not re-check for "tier 1" here, since the kit's own block would match.
4. Look for lines that say `kept_user_edit` or "so I kept your version". Tell the person in plain words which files the kit left alone because they had changed them, and offer to show the difference for each one (compare the file with its `.kit-new` copy).
5. Remind them to start a new session if hooks or skills changed.
