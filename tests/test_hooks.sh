#!/bin/bash
# Tests for the guard hooks. Pipes hook JSON on stdin and checks exit codes.
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
. "$DIR/helpers.sh"

FAKE="$(make_fake_home)"
trap 'rm -rf "$FAKE"' EXIT

# run_hook <hook-name> <json> -> sets RC and ERR
run_hook() {
  ERR="$(printf '%s' "$2" | HOME="$FAKE" bash "$ROOT/hooks/$1" 2>&1 >/dev/null)"
  RC=$?
}
expect() { # name hook json want
  run_hook "$2" "$3"
  assert_eq "$RC" "$4" "$1"
}

H=kit-home-scope-guard.sh
expect test_find_home_blocked $H '{"tool_name":"Bash","tool_input":{"command":"find ~ -name x"}}' 2
assert_contains_str() { case "$1" in *"$2"*) _pass;; *) _fail "$3: missing '$2'";; esac; }
assert_contains_str "$ERR" "Blocked: no searches across your whole home folder or disk. Search inside the project or vault folder instead." "message"
expect test_grep_tool_home_blocked $H '{"tool_name":"Grep","tool_input":{"path":"~","pattern":"x"}}' 2
expect test_scoped_tilde_search_allowed $H '{"tool_name":"Bash","tool_input":{"command":"grep -r foo ~/Code/app"}}' 0
expect test_ls_allowed $H '{"tool_name":"Bash","tool_input":{"command":"ls ~/Code"}}' 0
expect test_mdfind_unscoped_blocked $H '{"tool_name":"Bash","tool_input":{"command":"mdfind foo"}}' 2

P=kit-privacy-guard.sh
mkdir -p "$FAKE/.claude/vault-starter"
printf '# blocked folders\n\n~/Private\n~/My Secret Stuff\n' > "$FAKE/.claude/vault-starter/privacy-folders.txt"
expect test_privacy_read_blocked $P '{"tool_name":"Read","tool_input":{"file_path":"~/Private/a.txt"}}' 2
expect test_privacy_abs_blocked $P "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$FAKE/Private/a.txt\"}}" 2
expect test_privacy_bash_blocked $P '{"tool_name":"Bash","tool_input":{"command":"cat ~/Private/a.txt"}}' 2
expect test_privacy_space_path_blocked $P '{"tool_name":"Bash","tool_input":{"command":"ls \"~/My Secret Stuff/x\""}}' 2
expect test_privacy_other_allowed $P '{"tool_name":"Read","tool_input":{"file_path":"~/Code/a.txt"}}' 0
expect test_privacy_prefix_not_blocked $P '{"tool_name":"Read","tool_input":{"file_path":"~/PrivateNotes/a.txt"}}' 0
expect test_privacy_comment_ignored $P '{"tool_name":"Bash","tool_input":{"command":"echo blocked folders"}}' 0

rm "$FAKE/.claude/vault-starter/privacy-folders.txt"
expect test_privacy_no_file_allows $P '{"tool_name":"Read","tool_input":{"file_path":"~/Private/a.txt"}}' 0
: > "$FAKE/.claude/vault-starter/privacy-folders.txt"
expect test_privacy_empty_file_allows $P '{"tool_name":"Read","tool_input":{"file_path":"~/Private/a.txt"}}' 0

finish_tests
