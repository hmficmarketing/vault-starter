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

# --- fix round 1: bypass probes (each must block) ---
expect test_subshell_dollar_paren $H '{"tool_name":"Bash","tool_input":{"command":"echo $(find ~ -name x)"}}' 2
expect test_subshell_parens $H '{"tool_name":"Bash","tool_input":{"command":"(find ~ -name x)"}}' 2
expect test_subshell_backticks $H '{"tool_name":"Bash","tool_input":{"command":"echo `find ~ -name x`"}}' 2
expect test_bash_c $H '{"tool_name":"Bash","tool_input":{"command":"bash -c '"'"'find ~ -name x'"'"'"}}' 2
expect test_sh_c $H '{"tool_name":"Bash","tool_input":{"command":"sh -c \"find ~ -name x\""}}' 2
expect test_zsh_c $H '{"tool_name":"Bash","tool_input":{"command":"zsh -c '"'"'grep -r x ~'"'"'"}}' 2
expect test_xargs $H '{"tool_name":"Bash","tool_input":{"command":"echo | xargs grep -r x ~"}}' 2
expect test_legit_grep_still_ok $H '{"tool_name":"Bash","tool_input":{"command":"grep -r foo ~/Code/app"}}' 0
expect test_legit_find_still_ok $H '{"tool_name":"Bash","tool_input":{"command":"find ~/Code -name x"}}' 0
expect test_legit_subshell_ok $H '{"tool_name":"Bash","tool_input":{"command":"echo $(ls ~/Code)"}}' 0

printf '~/Private\n' > "$FAKE/.claude/vault-starter/privacy-folders.txt"
expect test_privacy_dotdot $P '{"tool_name":"Read","tool_input":{"file_path":"~/Code/../Private/a.txt"}}' 2
expect test_privacy_home_dot $P '{"tool_name":"Bash","tool_input":{"command":"cat $HOME/./Private/a.txt"}}' 2
expect test_privacy_double_slash $P "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$FAKE//Private/a.txt\"}}" 2
expect test_privacy_quoted_home $P '{"tool_name":"Bash","tool_input":{"command":"cat \"$HOME\"/Private/a.txt"}}' 2
expect test_privacy_braced_home $P '{"tool_name":"Bash","tool_input":{"command":"cat ${HOME}/Code/../Private/a.txt"}}' 2
expect test_privacy_normal_still_ok $P '{"tool_name":"Read","tool_input":{"file_path":"~/Code/../Code/a.txt"}}' 0
expect test_privacy_prefix_still_ok $P '{"tool_name":"Bash","tool_input":{"command":"cat ~/PrivateNotes/a.txt"}}' 0

# no python3 on PATH: hooks must block, not fail open
NOPY="$FAKE/nopy"; mkdir -p "$NOPY"
for hk in kit-home-scope-guard.sh kit-privacy-guard.sh; do
  printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | PATH="$NOPY" HOME="$FAKE" /bin/bash "$ROOT/hooks/$hk" >/dev/null 2>&1
  assert_eq "$?" "2" "test_no_python_blocks $hk"
done

# --- fix round 2 ---
expect test_xargs_pipe_echo_home $H '{"tool_name":"Bash","tool_input":{"command":"echo ~ | xargs grep -r foo"}}' 2
expect test_xargs_pipe_users_name $H '{"tool_name":"Bash","tool_input":{"command":"echo /Users/someone | xargs find -name x"}}' 2
expect test_bash_c_cd_then_search $H '{"tool_name":"Bash","tool_input":{"command":"bash -c \"cd ~ && grep -r x .\""}}' 2
expect test_xargs_scoped_pipe_ok $H '{"tool_name":"Bash","tool_input":{"command":"ls ~/Code | xargs grep -l foo"}}' 0

finish_tests
