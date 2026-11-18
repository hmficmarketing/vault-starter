# Vault Starter Kit: setup instructions

These instructions are for Claude. The person you are helping is on a Mac, uses the Claude desktop app, and does not use the terminal. You do all the work. Speak to them in plain words, short sentences, one question at a time. Say what you found, what you are about to do, and why.

## Rules while you set this up

- Only look in `~/.claude`, `~/Code` (or the folder where the person says their apps live), and the vault folder. Never search the whole home folder or the whole disk. Do not run `mdfind`, a recursive grep over the home folder, or a recursive find over it.
- If you cannot find something in a known place, ask the person. Do not hunt for it.
- GitHub. The person's install prompt already approves: signing in, cloning or pulling the kit, and reading their GitHub username. Ask first for everything else that touches GitHub: downloading an installer, creating a repo, pushing, or anything that changes their GitHub.
- Never print secrets, tokens, or passwords.
- Back up before touching an existing file. The installer does this for you. If you edit anything by hand, copy it to `<name>.bak` first.
- Never edit around an installer refusal. See step 5.
- Use absolute paths in every command. First run `echo $HOME` and use the full result (it looks like `/Users/<them>`). The `~` shortcut does not expand inside quotes, so it silently breaks things. Below, `<home>` means that full path.
- If a Mac pop-up appears that is not listed here, read it to the person and ask what they want to click.
- Plain words. The installer's "guards" are two small safety checks. One stops Claude from searching the whole computer. The other stops Claude from opening the private folders the person lists. Say it that way.

The only clicks the person should need are: downloading Obsidian (they may have done this already), the Xcode tools "Install" button if it appears, the GitHub installer window if you had to download it (Continue, Install, Mac password), and the GitHub sign-in in the browser.

## 0. First run or update?

Read `<home>/.claude/vault-starter/answers.json` if it exists. It is an update only if answers.json exists AND the vault folder it names (the `vault` key) still exists. If so, go straight to step 9. If answers.json exists but the vault folder is gone, or you are unsure, ask the person what they want. Otherwise this is a first run. Go to step 1.

## 1. Check the tools

Run each check. Fix only what fails.

- git: run `git --version`. On a fresh Mac this itself can pop up the Xcode tools installer. If that pop-up appeared, do not run `xcode-select --install`. Tell the person: "A box popped up. Click Install and wait for it to finish. Tell me when it is done." Then check again. If they closed the box, run `xcode-select --install` once and say the same.
- gh: run `gh --version`. If it fails:
  - If `brew --version` works, run `brew install gh`.
  - Otherwise, get the person's OK first: "I need to download the GitHub tool from GitHub's official releases. OK?" Downloading a release does not need a GitHub sign-in. Make a fresh temp folder with `mktemp -d`. Run `curl -s https://api.github.com/repos/cli/cli/releases/latest` and find the download link ending in `_macOS_universal.pkg` using grep and sed (no jq, no python), for example `grep -o 'https://[^"]*_macOS_universal.pkg' | head -1`. Download it into the temp folder with `curl -L -o`. Run `open "<pkg path>"` and tell the person: "An installer window opens. Click Continue, then Install, and enter your Mac password." Never use sudo. When it finishes, check `gh --version`, then delete the temp folder.
- Sign-in: run `gh auth status`. If it fails, do this:
  1. Make a temp folder with `mktemp -d`. Call it `<tmp>`.
  2. Start the login with your Bash tool's background option (run in background), not a plain `( ... ) &` that may be cleaned up when the call returns. The command is: `echo | gh auth login --hostname github.com --web --git-protocol https > "<tmp>/gh-login.log" 2>&1`
  3. Wait about 3 seconds, then read `<tmp>/gh-login.log`. It holds a one-time code that looks like `XXXX-XXXX`. Tell the person: "A browser page will open. Type this code: XXXX-XXXX, then click Authorize."
  4. If no code shows within 15 seconds, show the person the log in plain words and ask them what they see.
  5. Check `gh auth status` about every 10 seconds, for up to 5 minutes, until it succeeds.
  6. Run `gh auth setup-git`, so plain git pulls on the private repo work.
  7. Delete the temp folder.

## 2. Get the kit

If `<home>/Code` does not exist, create it. Tell the person they have no apps there yet. If `<home>/Code/vault-starter` does not exist, run `gh repo clone hmficmarketing/vault-starter <home>/Code/vault-starter`. If it exists, run `git -C <home>/Code/vault-starter pull`.

If the clone says the repo was not found, or could not resolve, the person has probably not accepted the GitHub invite yet. Ask them to open https://github.com/hmficmarketing/vault-starter/invitations in their browser and click Accept, then try the clone again.

## 3. Read what is already there

Look at these, and only these:

- `<home>/.claude/CLAUDE.md`, `<home>/.claude/settings.json`, `<home>/.claude/agents/`, and the names of the folders in `<home>/.claude/skills/`. Some may not exist. That is fine.
- A listing of `<home>/Code`, or ask the person where their apps live. If their apps live somewhere else, remember that folder and pass it as `--code-dir` in step 5.

Tell the person what you found in 3 short lines. Example: "You have a few skills already, no settings changes, and 4 apps in Code. I will not touch any of it without a backup."

## 4. Ask 5 questions

Ask one at a time. Wait for each answer.

1. Where should the vault go? Default `<home>/Vault`. Store it as a full absolute path. If that folder exists and is not empty, list its top level and ask: "Use this folder, or pick another?" Tell them the installer only adds missing files and never overwrites theirs, and that it backs up CLAUDE.md and settings.json before changing them.
2. What is your name?
3. What apps or projects do you have so far? A short list is fine. Pass it as `--apps "a, b"`. If they have none, leave `--apps` out.
4. Do you want the vault backed up to GitHub? Yes or no.
5. "What personal stuff should Claude never open? For example your texts, photos, email, or anything else."

For question 5, do not search. Use what you already know about where macOS keeps the data for each thing they named. Then confirm each candidate with `test -e "<abs path>"`. It checks the path exists and never lists contents. Never open or list inside those folders. Use full absolute paths, never `~`. Only keep paths that exist. If you are not sure where something lives, ask the person.
- For things with no folder on the Mac (for example email they only read in a browser), tell the person the guard cannot cover that.
- A path containing `;` cannot go in the list. Tell the person if one comes up.
Show them the final list in plain words and get a yes. If they name nothing, the list stays empty. You will pass the list as `--privacy "path1;path2"`. The installer saves it to `<home>/.claude/vault-starter/privacy-folders.txt`, and the privacy guard blocks Claude from reading those folders.

Also ask, only if their apps are not in `<home>/Code`: "Which folder holds your apps?" Pass it as `--code-dir "<folder>"`. Otherwise leave `--code-dir` out and the default `<home>/Code` is used.

Before you build the command, remove any double quote characters from the name and app values.

## 5. Run the installer

The installer asks no questions. It is safe to run again after a partial run. Run:

```
bash "<home>/Code/vault-starter/scripts/install.sh" --vault "<vault>" --name "<name>" --apps "<apps>" --privacy "<p1;p2>"
```

All paths in it are absolute.

- Leave out `--apps` if they have no apps.
- Leave out `--privacy` if the list is empty.
- Add `--code-dir "<folder>"` only if their apps live somewhere other than `<home>/Code`.
- Add `--no-tiers` if `<home>/.claude/CLAUDE.md` exists and already mentions "tier 1" (any capitalization). It means they already have a tier system, and the kit should not add its own. Ignore any text between `<!-- vault-starter:begin -->` and `<!-- vault-starter:end -->`, because that is the kit's own block. If CLAUDE.md is missing, do not pass the flag.
- Add `--git` if the person wants the vault to be a git repo (always add it if they said yes to backup in question 4).
- The last line it prints is `vault-starter: installed`. If you do not see it, it did not finish.
- If it says "You changed X, so I kept your version. The new one is at X.kit-new.", pass that on in plain words: "You had edited that file, so I left yours alone. The kit's newer version sits beside it with .kit-new on the end, if you want to compare."
- If the installer exits with an error, show the person its message in plain words. Explain what it means, offer to fix the cause, and wait for their OK before changing anything. Never edit around the refusal silently. The three refusals mean:
  - Broken markers in CLAUDE.md: "The kit's start and end markers in your CLAUDE.md file are damaged, so I am not sure where its section is. I will not guess."
  - Invalid settings.json: "Your settings.json file is not valid, so I cannot safely add the guards to it."
  - Memory linked elsewhere: "Your memory folder is linked to another place, and I will not point it somewhere else without your OK."
- If the test run or the installer fails partway, show the output and offer to re-run the installer.

## 6. Back up to GitHub (only if they said yes)

1. Check `git -C "<vault>" log -1` shows a commit. If not, stop and tell the person.
2. If the vault already has a remote (`git -C "<vault>" remote -v` prints something), stop and ask. Never push into an existing repo.
3. Get their login from `gh api user --jq .login`. Run `gh repo view <login>/vault`. If it exists, the name is taken. Ask for another name, and never push into an existing repo.
4. Before the push, show the person what would go up: run `git -C "<vault>" ls-files | head -50` and `git -C "<vault>" ls-files | wc -l`. Show the list and the count, and ask: "Is there anything here that should stay off GitHub?" If yes, help them remove it from the vault's git (`git rm --cached`) and add it to `.gitignore`, then check again.
5. Tell the person: "Everything in the vault folder will be uploaded to a private repo that only you can see." Show this command, get a yes, then run it:

```
gh repo create <login>/<repo name> --private --source "<vault>" --push
```

## 7. Check it works and show proof

Show the person the real output of each, not a summary.

- Run `bash "<home>/Code/vault-starter/tests/run.sh"`. It passes when its last line is `Suites: N run, 0 failed`. It runs in a throwaway folder and does not touch their files. If it fails, stop, show the output, and offer to re-run the installer.
- Prove the search guard works without running a risky search. Pipe a fake tool call into the installed hook and read the exit code:

  ```
  echo '{"tool_name":"Bash","tool_input":{"command":"find ~ -name x"}}' | bash "<home>/.claude/hooks/kit-home-scope-guard.sh"; echo "exit $?"
  ```

  Expect `exit 2`.
- If the privacy list is not empty, do the same for the privacy hook with a Read of a path inside the first privacy folder:

  ```
  echo '{"tool_name":"Read","tool_input":{"file_path":"<first privacy folder>/x"}}' | bash "<home>/.claude/hooks/kit-privacy-guard.sh"; echo "exit $?"
  ```

  Expect `exit 2`. (This only checks the path. It does not open anything.)
- If a guard blocks the proof command itself before it runs, that also counts as proof the guard is on. Say so.
- List the skills: `ls <home>/.claude/skills | grep '^kit-'`. You should see 6: kit-daily, kit-capture, kit-eod-flush, kit-handoff, kit-dream, kit-new-project.
- `git -C "<vault>" log -1` shows a commit (when `--git` was used).
- `git -C "<vault>" remote -v` shows the remote (when backup is on).

If any check fails, say so plainly and show the output. Do not call setup done.

Then tell the person: "Open a new chat in the Code tab of the Claude app and pick your folder, so the new skills and guards load."

## 8. Tell them how to open it

Check `test -d /Applications/Obsidian.app`. If it is missing, tell the person to download Obsidian from obsidian.md, and wait until they say it is installed.

Then tell the person: "Open Obsidian. Choose Open folder as vault. Pick the vault folder. Then read the note called How to use this vault."

## 9. Updates

When the person says "update my vault starter kit" (or step 0 sent you here):

1. Run `git -C <home>/Code/vault-starter pull`.
2. Read `<home>/.claude/vault-starter/answers.json`. Keys: `name`, `vault`, `apps` (a list, join it with ", " for `--apps`), `privacy`, `code_dir` (pass it as `--code-dir` if it is not `<home>/Code`), `no_tiers` and `git` (true or false). If the vault folder is gone, ask the person what to do.
3. If they want to change the private list:
   - To add a folder, confirm the full absolute path as in step 4, then pass `--privacy-add "<path1;path2>"`. It adds only the new folders and keeps the rest. Do not use `--privacy` for this: the privacy guard blocks any command that names a folder already on the list.
   - To remove a folder, run `open -e "<home>/.claude/vault-starter/privacy-folders.txt"`. Tell the person to delete that folder's line in TextEdit and save. Never edit that file yourself. The installer reads it as the source of truth on the next run.
   - Otherwise pass no privacy flag, so their list is kept.
4. Re-run the installer with those values. Add `--no-tiers` if `no_tiers` is true and `--git` if `git` is true. Do not re-check for "tier 1" here, since the kit's own block would match.
5. Look for lines that say `kept_user_edit` or "so I kept your version". Tell the person in plain words which files the kit left alone because they had changed them, and offer to show the difference for each one (compare the file with its `.kit-new` copy).
6. Tell them to open a new chat in the Code tab of the Claude app and pick their folder, if hooks or skills changed.
