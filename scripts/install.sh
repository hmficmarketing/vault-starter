#!/bin/bash
# Vault Starter Kit installer. Run by Claude Code on the person's behalf.
# Usage: install.sh --vault PATH --name NAME --apps "a, b" [--privacy "p1;p2"] [--no-tiers] [--git]
set -e
SRC="$(cd "$(dirname "$0")/.." && pwd -P)"
DEST="$HOME/.claude/vault-starter"

VAULT="$HOME/Vault"; NAME=""; APPS=""; PRIVACY=""; PRIVACY_SET=""; NO_TIERS=""; GIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --vault) VAULT="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --apps) APPS="$2"; shift 2 ;;
    --privacy) PRIVACY="$2"; PRIVACY_SET=1; shift 2 ;;
    --no-tiers) NO_TIERS=1; shift ;;
    --git) GIT=1; shift ;;
    *) echo "vault-starter: unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$NAME" ]; then echo "vault-starter: --name is required" >&2; exit 2; fi
command -v python3 >/dev/null 2>&1 || { echo "vault-starter: python3 is required" >&2; exit 2; }

# Copy the kit into ~/.claude/vault-starter/ (kit-owned folder; answers.json is kept).
mkdir -p "$DEST"
if [ "$SRC" != "$(cd "$DEST" && pwd -P)" ]; then
  for d in template skills hooks scripts; do
    if [ -d "$SRC/$d" ]; then
      mkdir -p "$DEST/$d"
      cp -R "$SRC/$d/." "$DEST/$d/"
    fi
  done
fi

ARGS=(install --vault "$VAULT" --name "$NAME" --apps "$APPS" --kit-dir "$DEST")
[ -n "$PRIVACY_SET" ] && ARGS+=(--privacy "$PRIVACY")
[ -n "$NO_TIERS" ] && ARGS+=(--no-tiers)
[ -n "$GIT" ] && ARGS+=(--git)
python3 -I -B "$DEST/scripts/kit.py" "${ARGS[@]}"

echo "vault-starter: installed"
