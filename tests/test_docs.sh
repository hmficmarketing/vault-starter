#!/bin/bash
# Docs: SETUP.md, INSTALL-PROMPT.txt, README.md
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "docs"
for f in SETUP.md INSTALL-PROMPT.txt README.md; do assert_file "$ROOT/$f"; done

for flag in --vault --name --apps --privacy --no-tiers --git; do
  assert_contains "$ROOT/SETUP.md" "$flag"
done
for s in "new session" "answers.json" "kept_user_edit" "exit 2" "kit-home-scope-guard.sh" "kit-privacy-guard.sh" "hmficmarketing/vault-starter"; do
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
assert_contains "$ROOT/SETUP.md" "new session"
assert_contains "$ROOT/SETUP.md" "gh auth setup-git"
assert_contains "$ROOT/SETUP.md" "one-time code"
assert_contains "$ROOT/INSTALL-PROMPT.txt" "one-time code"
assert_contains "$ROOT/SETUP.md" "_macOS_universal.pkg"
assert_contains "$ROOT/SETUP.md" "answers.json already exists"
assert_not_contains "$ROOT/SETUP.md" '"~/'
finish_tests
