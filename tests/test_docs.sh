#!/bin/bash
# Docs: SETUP.md, INSTALL-PROMPT.txt, README.md
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "docs"
for f in SETUP.md INSTALL-PROMPT.txt README.md; do assert_file "$ROOT/$f"; done

for flag in --vault --name --apps --privacy --privacy-add --code-dir --no-tiers --git; do
  assert_contains "$ROOT/SETUP.md" "$flag"
done
for s in "new chat" "answers.json" "kept_user_edit" "exit 2" "kit-home-scope-guard.sh" "kit-privacy-guard.sh" "hmficmarketing/vault-starter"; do
  assert_contains "$ROOT/SETUP.md" "$s"
done

n=$(wc -c < "$ROOT/INSTALL-PROMPT.txt" | tr -d ' ')
if [ "$n" -lt 800 ]; then _pass; else _fail "INSTALL-PROMPT.txt is $n chars"; fi

for f in SETUP.md INSTALL-PROMPT.txt README.md; do
  assert_not_contains "$ROOT/$f" "—"
done

# the only "find ~" in SETUP.md is inside the hook-test JSON (tool_input) line
bad=$(grep 'find ~' "$ROOT/SETUP.md" | grep -v 'tool_input' || true)
if [ -z "$bad" ]; then _pass; else _fail "SETUP.md has find ~ outside hook test: $bad"; fi
if grep 'find ~' "$ROOT/SETUP.md" | grep -q 'tool_input'; then _pass; else _fail "hook test JSON with find ~ missing"; fi

if grep -q 'privacy-folders\|--privacy' "$ROOT/SETUP.md"; then _pass; else _fail "SETUP.md privacy mention"; fi
assert_contains "$ROOT/SETUP.md" "new chat"
assert_contains "$ROOT/SETUP.md" "gh auth setup-git"
assert_contains "$ROOT/SETUP.md" "one-time code"
assert_contains "$ROOT/INSTALL-PROMPT.txt" "one-time code"
assert_contains "$ROOT/SETUP.md" "_macOS_universal.pkg"
assert_contains "$ROOT/SETUP.md" "answers.json exists AND"
assert_contains "$ROOT/SETUP.md" 'test -e'
assert_contains "$ROOT/SETUP.md" "Suites:"
assert_contains "$ROOT/SETUP.md" "Obsidian.app"
assert_not_contains "$ROOT/SETUP.md" "ls -d"
assert_not_contains "$ROOT/INSTALL-PROMPT.txt" "~"
assert_not_contains "$ROOT/SETUP.md" '"~/'
assert_contains "$ROOT/SETUP.md" "https://github.com/hmficmarketing/vault-starter/invitations"
assert_contains "$ROOT/SETUP.md" "run in background"
assert_contains "$ROOT/SETUP.md" 'ls-files | head -50'
assert_contains "$ROOT/SETUP.md" 'open -e'
assert_contains "$ROOT/SETUP.md" "Never edit that file yourself"
assert_contains "$ROOT/README.md" "accept the GitHub invite"
assert_contains "$ROOT/INSTALL-PROMPT.txt" "Accept the GitHub invite first."
assert_contains "$ROOT/skills/kit-new-project/SKILL.md" "code_dir"
assert_contains "$ROOT/skills/kit-new-project/SKILL.md" 'add a bullet'
finish_tests
