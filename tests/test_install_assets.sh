#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
. "$DIR/helpers.sh"
INSTALL="$ROOT/scripts/install.sh"

fake_home() { local h; h="$(make_fake_home)"; echo "${h//\/\///}"; }

run_install() {
  local h="$1"; shift
  HOME="$h" bash "$INSTALL" "$@" >"$h/install.out" 2>&1
}

# count_kit_cmds SETTINGS -> number of PreToolUse commands mentioning kit-
count_kit_cmds() {
  python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
n = 0
for e in d["hooks"]["PreToolUse"]:
    for h in e.get("hooks", []):
        if "/hooks/kit-" in h.get("command", ""):
            n += 1
print(n)' "$1"
}

test_assets_installed() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  local s
  for s in daily capture eod-flush handoff dream new-project; do
    assert_file "$h/.claude/skills/kit-$s/SKILL.md"
  done
  assert_file "$h/.claude/hooks/kit-home-scope-guard.sh"
  assert_file "$h/.claude/hooks/kit-privacy-guard.sh"
  local n
  n="$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$h/.claude/vault-starter/manifest.json")"
  assert_eq "$n" "8" "manifest entries"
  assert_eq "$(ls "$h/.claude/vault-starter/scripts" | grep -c __pycache__ || true)" "0" "no bytecode"
  rm -rf "$h"
}

# Simulate a changed kit: edit the installed kit copy, then re-run the installer
# against the same kit dir by pointing kit.py at it (install.sh would recopy the source).
reinstall_from_kit_copy() {
  local h="$1"
  HOME="$h" python3 -I -B "$h/.claude/vault-starter/scripts/kit.py" install \
    --vault "$h/Vault" --name Sam --apps "alpha" --kit-dir "$h/.claude/vault-starter" >"$h/install.out" 2>&1
}

test_user_edited_skill_kept() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  local d="$h/.claude/skills/kit-daily/SKILL.md"
  printf 'MY EDIT\n' >> "$d"
  printf 'NEW KIT LINE\n' >> "$h/.claude/vault-starter/skills/kit-daily/SKILL.md"
  reinstall_from_kit_copy "$h"
  assert_contains "$d" "MY EDIT"
  assert_not_contains "$d" "NEW KIT LINE"
  assert_contains "$d.kit-new" "NEW KIT LINE"
  assert_contains "$h/install.out" "You changed $d, so I kept your version. The new one is at $d.kit-new."
  # another kit change: .kit-new is overwritten, person's file still kept
  printf 'NEWER\n' >> "$h/.claude/vault-starter/skills/kit-daily/SKILL.md"
  reinstall_from_kit_copy "$h"
  assert_contains "$d" "MY EDIT"
  assert_contains "$d.kit-new" "NEWER"
  assert_contains "$h/install.out" "so I kept your version"
  rm -rf "$h"
}

test_unedited_skill_updated() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  printf 'NEW KIT LINE\n' >> "$h/.claude/vault-starter/skills/kit-daily/SKILL.md"
  reinstall_from_kit_copy "$h"
  local d="$h/.claude/skills/kit-daily/SKILL.md"
  if cmp -s "$d" "$h/.claude/vault-starter/skills/kit-daily/SKILL.md"; then _pass; else _fail "not updated"; fi
  if [ -e "$d.kit-new" ]; then _fail "unexpected .kit-new"; else _pass; fi
  rm -rf "$h"
}

test_settings_missing() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_file "$h/.claude/settings.json"
  assert_eq "$(count_kit_cmds "$h/.claude/settings.json")" "2" "kit commands"
  assert_contains "$h/.claude/settings.json" "bash \\\"$h/.claude/hooks/kit-privacy-guard.sh\\\""
  rm -rf "$h"
}

test_settings_existing_hooks_kept() {
  local h; h="$(fake_home)"
  mkdir -p "$h/.claude"
  cat > "$h/.claude/settings.json" <<'JSON'
{"model": "x", "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "echo foreign"}]}], "Stop": [{"hooks": [{"type": "command", "command": "echo stop"}]}]}}
JSON
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  local s="$h/.claude/settings.json"
  assert_contains "$s" '"model": "x"'
  assert_contains "$s" "echo foreign"
  assert_contains "$s" "echo stop"
  assert_eq "$(count_kit_cmds "$s")" "2" "kit commands"
  assert_eq "$(ls "$h/.claude" | grep -c 'settings.json.bak-vault-starter' || true)" "1" "one backup"
  assert_contains "$(ls "$h"/.claude/settings.json.bak-vault-starter-* | head -1)" "echo foreign"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_eq "$(count_kit_cmds "$s")" "2" "kit commands after rerun"
  assert_eq "$(ls "$h/.claude" | grep -c 'settings.json.bak-vault-starter' || true)" "1" "no new backup on rerun"
  rm -rf "$h"
}

test_existing_unquoted_command_not_duplicated() {
  local h; h="$(fake_home)"
  mkdir -p "$h/.claude"
  cat > "$h/.claude/settings.json" <<JSON
{"hooks": {"PreToolUse": [{"matcher": ".*", "hooks": [{"type": "command", "command": "bash $h/.claude/hooks/kit-privacy-guard.sh"}]}]}}
JSON
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_eq "$(count_kit_cmds "$h/.claude/settings.json")" "2" "no duplicate of existing"
  rm -rf "$h"
}

test_settings_spaces_in_home() {
  local base h; base="$(fake_home)"; h="$base/my home"; mkdir -p "$h"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_contains "$h/.claude/settings.json" "bash \\\"$h/.claude/hooks/kit-home-scope-guard.sh\\\""
  rm -rf "$base"
}

test_invalid_settings_refused() {
  local h; h="$(fake_home)"
  mkdir -p "$h/.claude"
  printf '{ not json' > "$h/.claude/settings.json"
  if run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"; then _fail "should fail"; else _pass; fi
  assert_eq "$(cat "$h/.claude/settings.json")" "{ not json" "settings untouched"
  assert_contains "$h/install.out" "isn't valid JSON, so I left it alone"
  assert_eq "$(ls "$h/.claude" | grep -c 'settings.json.bak' || true)" "0" "no backup"
  rm -rf "$h"
}

test_wrong_type_settings_refused() {
  local body
  for body in '{"hooks": []}' '{"hooks": {"PreToolUse": {}}}' '[]'; do
    local h; h="$(fake_home)"
    mkdir -p "$h/.claude"
    printf '%s' "$body" > "$h/.claude/settings.json"
    if run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"; then _fail "should fail: $body"; else _pass; fi
    assert_eq "$(cat "$h/.claude/settings.json")" "$body" "untouched: $body"
    assert_contains "$h/install.out" "left it alone"
    rm -rf "$h"
  done
}

test_empty_settings_ok() {
  local h; h="$(fake_home)"
  mkdir -p "$h/.claude"
  : > "$h/.claude/settings.json"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_eq "$(count_kit_cmds "$h/.claude/settings.json")" "2" "kit commands"
  rm -rf "$h"
}

test_privacy_from_flag() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy "$h/Private"
  assert_contains "$h/.claude/vault-starter/privacy-folders.txt" "$h/Private"
  local rc=0
  printf '{"tool_name":"Read","tool_input":{"file_path":"%s/Private/a.txt"}}' "$h" \
    | HOME="$h" bash "$h/.claude/hooks/kit-privacy-guard.sh" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "privacy hook exit"
  rm -rf "$h"
}

test_empty_privacy_list() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_file "$h/.claude/vault-starter/privacy-folders.txt"
  assert_eq "$(wc -c < "$h/.claude/vault-starter/privacy-folders.txt" | tr -d ' ')" "0" "empty file"
  rm -rf "$h"
}

test_hook_fires_after_install() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  local rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"find ~ -name x"}}' \
    | HOME="$h" bash "$h/.claude/hooks/kit-home-scope-guard.sh" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "home scope hook exit"
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"ls ."}}' \
    | HOME="$h" bash "$h/.claude/hooks/kit-home-scope-guard.sh" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "harmless command passes"
  rm -rf "$h"
}

test_edited_skill_unchanged_kit_silent() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  local d="$h/.claude/skills/kit-daily/SKILL.md"
  printf 'MY EDIT\n' >> "$d"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_contains "$d" "MY EDIT"
  if [ -e "$d.kit-new" ]; then _fail "unexpected .kit-new"; else _pass; fi
  assert_not_contains "$h/install.out" "kit-new"
  assert_not_contains "$h/install.out" "I kept your version"
  # stale .kit-new from an earlier kit change is removed once the kit stops changing
  printf 'old\n' > "$d.kit-new"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  if [ -e "$d.kit-new" ]; then _fail "stale .kit-new kept"; else _pass; fi
  rm -rf "$h"
}

test_privacy_kept_on_rerun() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy "$h/Private"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_contains "$h/.claude/vault-starter/privacy-folders.txt" "$h/Private"
  assert_contains "$h/.claude/vault-starter/answers.json" "$h/Private"
  local rc=0
  printf '{"tool_name":"Read","tool_input":{"file_path":"%s/Private/a.txt"}}' "$h" \
    | HOME="$h" bash "$h/.claude/hooks/kit-privacy-guard.sh" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "privacy hook still blocks"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy ""
  assert_eq "$(wc -c < "$h/.claude/vault-starter/privacy-folders.txt" | tr -d ' ')" "0" "explicit empty clears"
  assert_not_contains "$h/.claude/vault-starter/answers.json" "Private"
  rm -rf "$h"
}

priv_rc() { # home folder-name -> exit code of the privacy hook on a Read in that folder
  local rc=0
  printf '{"tool_name":"Read","tool_input":{"file_path":"%s/%s/a.txt"}}' "$1" "$2" \
    | HOME="$1" bash "$1/.claude/hooks/kit-privacy-guard.sh" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

test_privacy_add() {
  local h; h="$(fake_home)"
  local pf="$h/.claude/vault-starter/privacy-folders.txt"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy "$h/Private"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy-add "$h/Other"
  assert_contains "$pf" "$h/Private"
  assert_contains "$pf" "$h/Other"
  assert_eq "$(priv_rc "$h" Private)" "2" "Private still blocked"
  assert_eq "$(priv_rc "$h" Other)" "2" "Other blocked"
  assert_eq "$(priv_rc "$h" Code)" "0" "Code allowed"
  # re-run with no flag keeps both, answers.json lists both
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_contains "$pf" "$h/Private"
  assert_contains "$pf" "$h/Other"
  assert_contains "$h/.claude/vault-starter/answers.json" "$h/Private"
  assert_contains "$h/.claude/vault-starter/answers.json" "$h/Other"
  # duplicate add does not duplicate
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy-add "$h/Other;$h/Other/"
  assert_eq "$(grep -c "Other" "$pf")" "1" "no duplicate line"
  assert_eq "$(grep -c "Other" "$h/.claude/vault-starter/answers.json")" "1" "no duplicate in answers"
  rm -rf "$h"
}

test_privacy_add_keeps_comments_and_file_is_source_of_truth() {
  local h; h="$(fake_home)"
  local pf="$h/.claude/vault-starter/privacy-folders.txt"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy "$h/Private;$h/Gone"
  printf '# my list\n%s\n%s\n' "$h/Private" "$h/Gone" > "$pf"
  # the person deletes a line by hand, then the kit re-runs
  printf '# my list\n%s\n' "$h/Private" > "$pf"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_not_contains "$h/.claude/vault-starter/answers.json" "Gone"
  assert_contains "$h/.claude/vault-starter/answers.json" "Private"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy-add "$h/Other"
  assert_contains "$pf" "# my list"
  assert_contains "$pf" "$h/Other"
  assert_not_contains "$pf" "Gone"
  rm -rf "$h"
}

test_privacy_add_first_time_no_list() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --privacy-add "$h/Other"
  assert_contains "$h/.claude/vault-starter/privacy-folders.txt" "$h/Other"
  assert_eq "$(priv_rc "$h" Other)" "2" "Other blocked"
  rm -rf "$h"
}

test_code_dir_flag() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha, beta" --code-dir "$h/Projects"
  assert_file "$h/Projects/CLAUDE.md"
  assert_contains "$h/Projects/CLAUDE.md" "- alpha"
  if [ -e "$h/Code/CLAUDE.md" ]; then _fail "router written in ~/Code"; else _pass; fi
  assert_contains "$h/.claude/vault-starter/answers.json" "\"code_dir\": \"$h/Projects\""
  # re-run with no flag keeps using the saved folder
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha, beta, gamma"
  assert_contains "$h/Projects/CLAUDE.md" "- gamma"
  if [ -e "$h/Code/CLAUDE.md" ]; then _fail "router moved to ~/Code on re-run"; else _pass; fi
  rm -rf "$h"
}

test_code_dir_default() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_file "$h/Code/CLAUDE.md"
  assert_contains "$h/.claude/vault-starter/answers.json" "\"code_dir\": \"$h/Code\""
  rm -rf "$h"
}

test_memory_section_installed() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --no-tiers
  assert_contains "$h/.claude/CLAUDE.md" "## Memory"
  assert_contains "$h/.claude/CLAUDE.md" "decided (Sam said it)"
  assert_not_contains "$h/.claude/CLAUDE.md" "{{NAME}}"
  assert_contains "$h/Vault/CLAUDE.md" "decided (Sam said it)"
  rm -rf "$h"
}

test_vault_gitignore_secrets() {
  for p in '.env' '.env.*' '!.env.example' '*.pem' '*.key'; do
    assert_contains "$ROOT/template/vault/.gitignore" "$p"
  done
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  echo "- $t"
  "$t"
done
finish_tests
