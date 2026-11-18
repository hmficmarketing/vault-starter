#!/bin/bash
# Runs every tests/test_*.sh. Exits non-zero if any fail.
DIR="$(cd "$(dirname "$0")" && pwd)"
failed=0
total=0
for t in "$DIR"/test_*.sh; do
  [ -f "$t" ] || continue
  total=$((total + 1))
  echo "== $(basename "$t")"
  if ! bash "$t"; then failed=$((failed + 1)); fi
done
echo "Suites: $total run, $failed failed"
[ "$failed" -eq 0 ]
