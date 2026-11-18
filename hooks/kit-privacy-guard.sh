#!/bin/bash
# Blocks any tool call that mentions a folder listed in
# ~/.claude/vault-starter/privacy-folders.txt (one path per line, ~ allowed).
# No folders are built in. Missing or empty file = nothing blocked.
# Exit 2 = block; the message goes back to Claude.
# Matching: (1) each string and each shell token is expanded (~, $HOME, ${HOME}),
# normalized (.., ., //) and compared to the folder; (2) a boundary regex over the
# raw text. Out of scope: symlinks, globs, and relative paths after a `cd`.
command -v python3 >/dev/null 2>&1 || { echo "Blocked: kit guard needs python3. Install Apple's command line tools." >&2; exit 2; }
input=$(cat)
HOOK_INPUT="$input" python3 -I - <<'PY'
import json, os, re, shlex, sys

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

strs = list(strings(data.get("tool_input") or {}))
text = "\n".join(strs)

def expand(t):
    if t == "~" or t.startswith("~/"):
        t = HOME + t[1:]
    return t.replace("${HOME}", HOME).replace("$HOME", HOME)

def candidates():
    for s in strs:
        yield s
        try:
            toks = shlex.split(s, posix=True)
        except ValueError:
            toks = s.split()
        for t in toks:
            yield t
            if "=" in t:
                yield t.split("=", 1)[1]

abs_folders = []
for shown, alts in forms:
    abs_folders.append((shown, os.path.normpath(re.sub(r"/+", "/", expand(alts[1] if len(alts) > 1 else alts[0])))))

def deny(shown):
    print("Blocked: this touches a folder you marked private (%s). "
          "Ask the user instead of reading or changing it." % shown, file=sys.stderr)
    sys.exit(2)

for c in candidates():
    e = expand(c)
    if not e.startswith("/"):
        continue
    n = os.path.normpath(re.sub(r"/+", "/", e))
    for shown, f in abs_folders:
        if n == f or n.startswith(f + "/"):
            deny(shown)

for shown, alts in forms:
    for a in alts:
        # must end at a path boundary so ~/Private does not match ~/PrivateNotes
        if re.search(r"(?<![A-Za-z0-9_.~-])" + re.escape(a) + r"(?![A-Za-z0-9_.-])", text):
            print("Blocked: this touches a folder you marked private (%s). "
                  "Ask the user instead of reading or changing it." % shown, file=sys.stderr)
            sys.exit(2)
sys.exit(0)
PY
