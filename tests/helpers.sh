#!/bin/bash
# Shared test helpers. bash 3.2 compatible.
PASS_COUNT=0
FAIL_COUNT=0

make_fake_home() {
  mktemp -d "${TMPDIR:-/tmp}/vault-starter-test.XXXXXX"
}

_pass() { PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $1"; }

assert_file() {
  if [ -f "$1" ]; then _pass; else _fail "missing file: $1"; fi
}

assert_contains() {
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then _pass; else _fail "$1 does not contain: $2"; fi
}

assert_not_contains() {
  if [ -f "$1" ] && ! grep -qF -- "$2" "$1"; then _pass; else _fail "$1 should not contain: $2"; fi
}

assert_eq() {
  if [ "$1" = "$2" ]; then _pass; else _fail "${3:-assert_eq}: expected '$2', got '$1'"; fi
}

finish_tests() {
  echo "  $PASS_COUNT passed, $FAIL_COUNT failed"
  [ "$FAIL_COUNT" -eq 0 ]
}
