#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
. "$DIR/helpers.sh"
T="$ROOT/template"
V="$T/vault"

for f in CLAUDE.md "How to use this vault.md" .gitignore \
  Inbox/.gitkeep Projects/.gitkeep Knowledge/.gitkeep "Daily Notes/.gitkeep" Archives/.gitkeep \
  Templates/Daily.md Templates/Project.md \
  .obsidian/app.json .obsidian/daily-notes.json .obsidian/templates.json .obsidian/core-plugins.json; do
  assert_file "$V/$f"
done
assert_file "$T/code-router/CLAUDE.md"
assert_file "$T/app/CLAUDE.md"
assert_file "$T/global/kit-section.md"

for j in app daily-notes templates core-plugins; do
  if python3 -I -m json.tool "$V/.obsidian/$j.json" >/dev/null 2>&1; then _pass; else _fail "invalid JSON: $j.json"; fi
done

assert_contains "$V/.obsidian/daily-notes.json" '"Daily Notes"'
assert_contains "$V/.obsidian/daily-notes.json" '"Templates/Daily"'
assert_contains "$V/.obsidian/templates.json" '"Templates"'
for p in daily-notes templates file-explorer search backlinks graph; do
  assert_contains "$V/.obsidian/core-plugins.json" "\"$p\""
done
for p in '.obsidian/workspace*.json' '.trash/' '.DS_Store'; do
  assert_contains "$V/.gitignore" "$p"
done

K="$T/global/kit-section.md"
assert_contains "$K" '<!-- kit:tiers -->'
assert_contains "$K" '<!-- /kit:tiers -->'
assert_not_contains "$K" 'vault-starter:begin'
assert_contains "$K" '{{VAULT_PATH}}'
assert_contains "$K" 'CLAUDE.local.md'
assert_contains "$K" "I'll paste it in myself. Before any commit, check that no .env or key file is staged."

for s in "What this is" "Stack" "How to run" "Current state" "Decisions" "Next"; do
  assert_contains "$T/app/CLAUDE.md" "## $s"
done
for s in /kit-daily /kit-capture /kit-new-project /kit-eod-flush /kit-handoff /kit-dream "update my vault starter kit"; do
  assert_contains "$V/How to use this vault.md" "$s"
done
assert_contains "$T/code-router/CLAUDE.md" '{{APPS_LIST}}'
assert_contains "$V/CLAUDE.md" '{{NAME}}'
assert_contains "$V/Templates/Daily.md" '{{date}}'

finish_tests
