#!/bin/bash
# Checks the 6 kit skills. bash 3.2 compatible.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/tests/helpers.sh"

for n in daily capture eod-flush handoff dream new-project; do
  d="$DIR/skills/kit-$n"
  f="$d/SKILL.md"
  assert_file "$f"
  [ -f "$f" ] || continue
  name=$(sed -n 's/^name: *//p' "$f" | head -1)
  assert_eq "$name" "kit-$n" "name matches folder for kit-$n"
  desc=$(sed -n 's/^description: *//p' "$f" | head -1)
  len=${#desc}
  if [ "$len" -gt 0 ] && [ "$len" -lt 300 ]; then _pass; else _fail "kit-$n description length $len"; fi
  size=$(wc -c < "$f" | tr -d ' ')
  if [ "$size" -lt 4096 ]; then _pass; else _fail "kit-$n is $size bytes"; fi
  assert_not_contains "$f" "/Users/"
done
finish_tests
