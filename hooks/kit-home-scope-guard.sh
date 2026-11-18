#!/bin/bash
# Blocks file searches across the whole home folder or the whole disk.
# Such searches trigger macOS permission prompts (iCloud Drive, Music, Photos)
# and walk into personal folders. Exit 2 = block; the message goes back to Claude.
input=$(cat)
HOOK_INPUT="$input" python3 -I - <<'PY'
import json, os, re, shlex, sys

HOME = os.path.expanduser("~").rstrip("/")
BROAD = {"~", "~/", "$HOME", "$HOME/", "${HOME}", "${HOME}/", HOME, HOME + "/",
         "/", "/Users", "/Users/", "/System/Volumes/Data", "/System/Volumes/Data/"}
SEARCHERS = {"find", "mdfind", "grep", "egrep", "fgrep", "rg", "ag", "ack", "fd", "fdfind",
             "locate", "tree", "du"}
MSG = ("Blocked: no searches across your whole home folder or disk. "
       "Search inside the project or vault folder instead.")

def block():
    print(MSG, file=sys.stderr)
    sys.exit(2)

def norm(tok):
    return tok.strip().strip("'\"")

def is_broad(tok):
    t = norm(tok)
    return t in BROAD or t in {"~/*", HOME + "/*", "/*", "/Users/*"}

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
except Exception:
    sys.exit(0)
tool = data.get("tool_name", "")
ti = data.get("tool_input") or {}

if tool in ("Grep", "Glob"):
    p = ti.get("path") or ""
    if p and is_broad(p):
        block()
    pat = ti.get("pattern") or ""
    if tool == "Glob" and (pat.startswith(HOME + "/**") or pat.startswith("~/**") or pat.startswith("/**")):
        block()
    sys.exit(0)

if tool != "Bash":
    sys.exit(0)
cmd = ti.get("command") or ""

for part in re.split(r"\|\||&&|;|\||\n", cmd):
    try:
        toks = shlex.split(part, posix=True)
    except ValueError:
        toks = part.split()
    while toks and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]) or toks[0] in ("sudo", "timeout", "nice", "command", "exec")):
        toks = toks[1:]
        if toks and re.match(r"^\d+[smh]?$", toks[0]):
            toks = toks[1:]
    if not toks:
        continue
    prog = os.path.basename(toks[0])
    args = toks[1:]
    if prog == "mdfind":
        if "-onlyin" not in args:
            block()
        i = args.index("-onlyin")
        if i + 1 >= len(args) or is_broad(args[i + 1]):
            block()
        continue
    if prog == "ls" and any(a.startswith("-") and "R" in a for a in args) and any(is_broad(a) for a in args):
        block()
    if prog in SEARCHERS and any(is_broad(a) for a in args):
        block()

if re.search(r"(^|[;&|\s])cd\s+(~/?|\$HOME/?|\$\{HOME\}/?|" + re.escape(HOME) + r"/?|/)(\s|;|&|$)", cmd) and \
   re.search(r"(^|[;&|\s])(find\s+\.|grep\s+-[A-Za-z]*[rR]|rg\s|fd\s|ag\s|tree(\s|$)|du\s)", cmd):
    block()
sys.exit(0)
PY
