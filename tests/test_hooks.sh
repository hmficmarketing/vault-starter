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

# --- final fix: lone "/" as a pattern or find expression is not a broad path ---
expect test_grep_v_slash_ok $H '{"tool_name":"Bash","tool_input":{"command":"grep -rn foo ~/Code/app | grep -v /"}}' 0
expect test_grep_c_slash_ok $H '{"tool_name":"Bash","tool_input":{"command":"grep -c / paths.txt"}}' 0
expect test_find_path_slash_ok $H '{"tool_name":"Bash","tool_input":{"command":"find . -path / -prune"}}' 0
expect test_grep_rn_home_blocked $H '{"tool_name":"Bash","tool_input":{"command":"grep -rn foo ~"}}' 2
expect test_grep_r_home_blocked $H '{"tool_name":"Bash","tool_input":{"command":"grep -r foo ~"}}' 2
expect test_rg_root_blocked $H '{"tool_name":"Bash","tool_input":{"command":"rg foo /"}}' 2
expect test_find_root_blocked $H '{"tool_name":"Bash","tool_input":{"command":"find / -name x"}}' 2
expect test_find_L_home_blocked $H '{"tool_name":"Bash","tool_input":{"command":"find -L ~ -name x"}}' 2
expect test_grep_e_pattern_then_path_blocked $H '{"tool_name":"Bash","tool_input":{"command":"grep -r -e foo /"}}' 2
expect test_grep_nonrecursive_slash_ok $H '{"tool_name":"Bash","tool_input":{"command":"grep foo /"}}' 0

# --- final fix: command prefixes and cd forms ---
expect test_env_find $H '{"tool_name":"Bash","tool_input":{"command":"env find ~ -name x"}}' 2
expect test_env_var_find $H '{"tool_name":"Bash","tool_input":{"command":"env LC_ALL=C find ~ -name x"}}' 2
expect test_time_find $H '{"tool_name":"Bash","tool_input":{"command":"time find ~ -name x"}}' 2
expect test_nohup_find $H '{"tool_name":"Bash","tool_input":{"command":"nohup find ~ -name x"}}' 2
expect test_caffeinate_find $H '{"tool_name":"Bash","tool_input":{"command":"caffeinate find ~ -name x"}}' 2
expect test_eval_find $H '{"tool_name":"Bash","tool_input":{"command":"eval \"find ~ -name x\""}}' 2
expect test_cd_quoted_home $H '{"tool_name":"Bash","tool_input":{"command":"cd \"$HOME\" && grep -r x ."}}' 2
expect test_cd_braced_home $H '{"tool_name":"Bash","tool_input":{"command":"cd ${HOME} && grep -r x ."}}' 2
expect test_cd_bare $H '{"tool_name":"Bash","tool_input":{"command":"cd && grep -r x ."}}' 2
expect test_cd_code_ok $H '{"tool_name":"Bash","tool_input":{"command":"cd ~/Code && grep -r x ."}}' 0
expect test_env_scoped_ok $H '{"tool_name":"Bash","tool_input":{"command":"env FOO=1 find ~/Code -name x"}}' 0

# --- final fix: very large tool input (over 1 MB) is still checked ---
BIG="$FAKE/big"; mkdir -p "$BIG"
python3 -I - "$BIG" <<'PYEOF'
import json, sys
b = 'a' * 1500000
d = sys.argv[1]
json.dump({'tool_name': 'Write', 'tool_input': {'file_path': '~/Private/x.txt', 'content': b}}, open(d + '/priv.json', 'w'))
json.dump({'tool_name': 'Write', 'tool_input': {'file_path': '~/Code/x.txt', 'content': b}}, open(d + '/ok.json', 'w'))
json.dump({'tool_name': 'Bash', 'tool_input': {'command': 'echo ' + b}}, open(d + '/okbash.json', 'w'))
json.dump({'tool_name': 'Bash', 'tool_input': {'command': 'echo ' + b + '; find ~ -name x'}}, open(d + '/badbash.json', 'w'))
PYEOF
run_file() { HOME="$FAKE" bash "$ROOT/hooks/$1" < "$2" >/dev/null 2>&1; RC=$?; }
run_file $P "$BIG/priv.json";    assert_eq "$RC" "2" "test_big_private_write_blocked"
run_file $P "$BIG/ok.json";      assert_eq "$RC" "0" "test_big_harmless_write_privacy_ok"
run_file $H "$BIG/ok.json";      assert_eq "$RC" "0" "test_big_harmless_write_home_ok"
run_file $H "$BIG/okbash.json";  assert_eq "$RC" "0" "test_big_harmless_bash_ok"
run_file $H "$BIG/badbash.json"; assert_eq "$RC" "2" "test_big_bad_bash_blocked"

finish_tests
