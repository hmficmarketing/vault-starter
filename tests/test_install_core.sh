#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
. "$DIR/helpers.sh"
INSTALL="$ROOT/scripts/install.sh"
KIT="$ROOT/scripts/kit.py"
MB="<!-- vault-starter:begin -->"
ME="<!-- vault-starter:end -->"

# TMPDIR may end in a slash; collapse "//" so path comparisons are exact.
fake_home() { local h; h="$(make_fake_home)"; echo "${h//\/\///}"; }

# run_install FAKE_HOME args... (never touches the real HOME)
run_install() {
  local h="$1"; shift
  HOME="$h" bash "$INSTALL" "$@" >"$h/install.out" 2>&1
}

check_fresh() {
  local h="$1" v="$2"
  for d in Inbox Projects Knowledge "Daily Notes" Archives Templates .obsidian; do
    if [ -d "$v/$d" ]; then _pass; else _fail "missing vault folder: $d"; fi
  done
  assert_file "$v/CLAUDE.md"
  assert_contains "$v/CLAUDE.md" "Sam's vault"
  assert_not_contains "$v/CLAUDE.md" "{{NAME}}"
  assert_not_contains "$v/CLAUDE.md" "{{VAULT_PATH}}"
  assert_contains "$v/CLAUDE.md" "$v"
  assert_contains "$h/.claude/CLAUDE.md" "$MB"
  assert_contains "$h/.claude/CLAUDE.md" "$ME"
  assert_contains "$h/.claude/CLAUDE.md" "$v"
  # lowercase Obsidian placeholders survive
  assert_contains "$v/Templates/Daily.md" "{{date}}"
  assert_contains "$v/Templates/Project.md" "{{title}}"
  local enc
  enc="$(python3 -I "$KIT" encode "$v")"
  local mem="$h/.claude/projects/$enc/memory"
  if [ -L "$mem" ]; then _pass; else _fail "memory path is not a symlink: $mem"; fi
  assert_eq "$(readlink "$mem")" "$v/.claude/memory" "memory symlink target"
  assert_contains "$h/Code/CLAUDE.md" "- alpha"
  assert_contains "$h/Code/CLAUDE.md" "- beta"
  assert_eq "$(tail -n 1 "$h/install.out")" "vault-starter: installed" "last line"
  assert_file "$h/.claude/vault-starter/answers.json"
  assert_file "$h/.claude/vault-starter/template/vault/CLAUDE.md"
  assert_file "$h/.claude/vault-starter/scripts/kit.py"
}

test_fresh_install() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha, beta"
  check_fresh "$h" "$h/Vault"
  assert_contains "$h/.claude/CLAUDE.md" "Tier 1"
  rm -rf "$h"
}

test_existing_claude_md_preserved() {
  local h; h="$(fake_home)"
  mkdir -p "$h/.claude"
  printf 'MY RULES\n' > "$h/.claude/CLAUDE.md"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_contains "$h/.claude/CLAUDE.md" "MY RULES"
  assert_contains "$h/.claude/CLAUDE.md" "$MB"
  local n; n="$(ls "$h/.claude" | grep -c '^CLAUDE.md.bak-vault-starter-')"
  assert_eq "$n" "1" "backup count"
  assert_contains "$(ls "$h"/.claude/CLAUDE.md.bak-vault-starter-* | head -1)" "MY RULES"
  rm -rf "$h"
}

test_text_outside_markers_untouched() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  printf 'AFTER\n' >> "$h/.claude/CLAUDE.md"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_eq "$(grep -c '^AFTER$' "$h/.claude/CLAUDE.md")" "1" "AFTER count"
  assert_eq "$(grep -cF "$MB" "$h/.claude/CLAUDE.md")" "1" "begin marker count"
  assert_eq "$(grep -cF "$ME" "$h/.claude/CLAUDE.md")" "1" "end marker count"
  rm -rf "$h"
}

test_run_twice_idempotent() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha, beta"
  (cd "$h" && find . -not -name '*.bak-vault-starter-*' -not -name install.out -not -name 'list[12]' | sort) > "$h/list1"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha, beta"
  (cd "$h" && find . -not -name '*.bak-vault-starter-*' -not -name install.out -not -name 'list[12]' | sort) > "$h/list2"
  if cmp -s "$h/list1" "$h/list2"; then _pass; else _fail "listings differ"; diff "$h/list1" "$h/list2"; fi
  assert_eq "$(grep -cF "$MB" "$h/.claude/CLAUDE.md")" "1" "marker pair"
  assert_eq "$(grep -c '^- alpha$' "$h/Code/CLAUDE.md")" "1" "alpha bullet once"
  local n; n="$(ls "$h/.claude" | grep -c 'bak-vault-starter' || true)"
  assert_eq "$n" "0" "no backups when nothing changed"
  rm -rf "$h"
}

test_existing_vault_file_not_replaced() {
  local h; h="$(fake_home)"
  mkdir -p "$h/Vault"
  printf 'MINE\n' > "$h/Vault/CLAUDE.md"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"
  assert_eq "$(cat "$h/Vault/CLAUDE.md")" "MINE" "vault CLAUDE.md"
  assert_file "$h/Vault/Inbox/.gitkeep"
  rm -rf "$h"
}

test_existing_memory_moved_not_lost() {
  local h; h="$(fake_home)"
  local v="$h/Vault"
  local enc; enc="$(python3 -I "$KIT" encode "$v")"
  mkdir -p "$h/.claude/projects/$enc/memory"
  printf 'old a\n' > "$h/.claude/projects/$enc/memory/a.md"
  printf 'old b\n' > "$h/.claude/projects/$enc/memory/b.md"
  mkdir -p "$v/.claude/memory"
  printf 'new b\n' > "$v/.claude/memory/b.md"
  run_install "$h" --vault "$v" --name Sam --apps "alpha"
  assert_file "$v/.claude/memory/a.md"
  assert_contains "$v/.claude/memory/a.md" "old a"
  assert_contains "$v/.claude/memory/b.md" "new b"
  assert_contains "$v/.claude/memory/b.md.from-claude.md" "old b"
  if [ -L "$h/.claude/projects/$enc/memory" ]; then _pass; else _fail "old memory path not a symlink"; fi
  rm -rf "$h"
}

test_vault_path_with_spaces() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/My Vault" --name Sam --apps "alpha, beta"
  check_fresh "$h" "$h/My Vault"
  rm -rf "$h"
}

test_no_tiers() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --no-tiers
  if grep -qi "tier 1" "$h/.claude/CLAUDE.md"; then _fail "tier text present with --no-tiers"; else _pass; fi
  assert_not_contains "$h/.claude/CLAUDE.md" "kit:tiers"
  assert_contains "$h/.claude/CLAUDE.md" "Secrets rule"
  rm -rf "$h"
}

test_answers_saved() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha, beta" --privacy "/one;/two" --no-tiers
  local a="$h/.claude/vault-starter/answers.json"
  assert_contains "$a" '"name": "Sam"'
  assert_contains "$a" '"alpha"'
  assert_contains "$a" '"beta"'
  assert_contains "$a" "\"/one\""
  assert_contains "$a" "\"/two\""
  assert_contains "$a" "$h/Vault"
  assert_contains "$a" '"no_tiers": true'
  rm -rf "$h"
}

test_git_flag() {
  local h; h="$(fake_home)"
  run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha" --git
  if [ -d "$h/Vault/.git" ]; then _pass; else _fail "no .git"; fi
  assert_eq "$(HOME="$h" git -C "$h/Vault" rev-list --count HEAD 2>/dev/null)" "1" "commit count"
  assert_eq "$(HOME="$h" git -C "$h/Vault" config --global user.name 2>/dev/null || echo none)" "none" "global git config untouched"
  rm -rf "$h"
}

test_encode_project_dir() {
  assert_eq "$(python3 -I "$KIT" encode "/Users/a/My Vault")" "-Users-a-My-Vault" "encode"
}

test_broken_markers_refused() {
  local variant content
  for variant in orphan_begin orphan_end reversed; do
    local h; h="$(fake_home)"
    mkdir -p "$h/.claude"
    case "$variant" in
      orphan_begin) content="TOP\n$MB\nold kit\nUSER TEXT KEEP\n" ;;
      orphan_end) content="TOP\nold kit\n$ME\nUSER TEXT KEEP\n" ;;
      reversed) content="TOP\n$ME\nmid\n$MB\nUSER TEXT KEEP\n" ;;
    esac
    printf "$content" > "$h/.claude/CLAUDE.md"
    cp "$h/.claude/CLAUDE.md" "$h/orig"
    if run_install "$h" --vault "$h/Vault" --name Sam --apps "alpha"; then _fail "$variant: install should fail"; else _pass; fi
    if cmp -s "$h/orig" "$h/.claude/CLAUDE.md"; then _pass; else _fail "$variant: file changed"; fi
    assert_eq "$(ls "$h/.claude" | grep -c 'bak-vault-starter' || true)" "0" "$variant: no backup"
    assert_contains "$h/install.out" "broken vault-starter section"
    rm -rf "$h"
  done
}

test_memory_symlink_elsewhere_refused() {
  local h; h="$(fake_home)"
  local v="$h/Vault"
  local enc; enc="$(python3 -I "$KIT" encode "$v")"
  mkdir -p "$h/other" "$h/.claude/projects/$enc"
  printf 'keep\n' > "$h/other/x.md"
  ln -s "$h/other" "$h/.claude/projects/$enc/memory"
  if run_install "$h" --vault "$v" --name Sam --apps "alpha"; then _fail "should refuse"; else _pass; fi
  assert_eq "$(readlink "$h/.claude/projects/$enc/memory")" "$h/other" "link unchanged"
  assert_contains "$h/other/x.md" "keep"
  assert_contains "$h/install.out" "$h/other"
  rm -rf "$h"
}

test_memory_relative_symlink_accepted() {
  local h; h="$(fake_home)"
  local v="$h/Vault"
  local enc; enc="$(python3 -I "$KIT" encode "$v")"
  mkdir -p "$v/.claude/memory" "$h/.claude/projects/$enc"
  (cd "$h/.claude/projects/$enc" && ln -s "../../../Vault/.claude/memory" memory)
  if run_install "$h" --vault "$v" --name Sam --apps "alpha"; then _pass; else _fail "relative link refused"; fi
  assert_eq "$(readlink "$h/.claude/projects/$enc/memory")" "../../../Vault/.claude/memory" "link unchanged"
  rm -rf "$h"
}

for t in test_fresh_install test_existing_claude_md_preserved test_text_outside_markers_untouched \
  test_run_twice_idempotent test_existing_vault_file_not_replaced test_existing_memory_moved_not_lost \
  test_vault_path_with_spaces test_no_tiers test_answers_saved test_git_flag test_encode_project_dir \
  test_broken_markers_refused test_memory_symlink_elsewhere_refused test_memory_relative_symlink_accepted; do
  echo " - $t"
  $t
done
finish_tests
