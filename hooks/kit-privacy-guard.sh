#!/bin/bash
# Blocks any tool call that mentions a folder listed in
# ~/.claude/vault-starter/privacy-folders.txt (one path per line, ~ allowed).
# No folders are built in. Missing or empty file = nothing blocked.
# Exit 2 = block; the message goes back to Claude.
input=$(cat)
HOOK_INPUT="$input" python3 -I - <<'PY'
import json, os, re, sys

HOME = os.path.expanduser("~").rstrip("/")
LIST = os.path.join(HOME, ".claude", "vault-starter", "privacy-folders.txt")

try:
    with open(LIST, encoding="utf-8") as f:
        lines = f.read().splitlines()
except Exception:
    sys.exit(0)

forms = []
for line in lines:
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    line = line.rstrip("/")
    if line.startswith("~/"):
        rel = line[2:]
    elif line.startswith(HOME + "/"):
        rel = line[len(HOME) + 1:]
    elif line.startswith("$HOME/"):
        rel = line[6:]
    else:
        rel = None
    if rel is not None:
        rel = rel.rstrip("/")
        if not rel:
            continue
        forms.append((line, ["~/" + rel, HOME + "/" + rel, "$HOME/" + rel, "${HOME}/" + rel]))
    elif line.startswith("/"):
        forms.append((line, [line]))

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
except Exception:
    sys.exit(0)

def strings(v):
    if isinstance(v, str):
        yield v
    elif isinstance(v, dict):
        for x in v.values():
            yield from strings(x)
    elif isinstance(v, list):
        for x in v:
            yield from strings(x)

text = "\n".join(strings(data.get("tool_input") or {}))
for shown, alts in forms:
    for a in alts:
        # must end at a path boundary so ~/Private does not match ~/PrivateNotes
        if re.search(r"(?<![A-Za-z0-9_.~-])" + re.escape(a) + r"(?![A-Za-z0-9_.-])", text):
            print("Blocked: this touches a folder you marked private (%s). "
                  "Ask the user instead of reading or changing it." % shown, file=sys.stderr)
            sys.exit(2)
sys.exit(0)
PY
