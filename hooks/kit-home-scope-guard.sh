#!/bin/bash
# Blocks file searches across the whole home folder or the whole disk.
# Such searches trigger macOS permission prompts (iCloud Drive, Music, Photos)
# and walk into personal folders. Exit 2 = block; the message goes back to Claude.
command -v python3 >/dev/null 2>&1 || { echo "Blocked: kit guard needs python3. Install Apple's command line tools." >&2; exit 2; }
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
    return t in BROAD or t in {"~/*", HOME + "/*", "/*", "/Users/*"} or bool(re.fullmatch(r"/Users/[^/]+/?", t))

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

SPLIT = r"\|\||&&|;|\||\n|\$\(|`|\(|\)"
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
XARGS_VAL = {"-I", "-n", "-P", "-L", "-s", "-d", "-E", "-J", "-a"}

CD_RE = re.compile(r"(^|[;&|\s])cd\s+(~/?|\$HOME/?|\$\{HOME\}/?|" + re.escape(HOME) + r"/?|/)(\s|;|&|$)")
REC_RE = re.compile(r"(^|[;&|\s])(find\s+\.|grep\s+-[A-Za-z]*[rR]|rg\s|fd\s|ag\s|tree(\s|$)|du\s)")

SHELLC_RE = re.compile(r"\b(bash|sh|zsh|dash|ksh)\s+-[A-Za-z]*c\s+(['\"])(.*?)\2")

def xargs_recursive(prog, args):
    if prog in ("find", "rg", "fd", "fdfind", "ag", "ack", "tree", "du", "locate"):
        return True
    if prog == "mdfind":
        return "-onlyin" not in args
    if prog in ("grep", "egrep", "fgrep"):
        return any((a.startswith("-") and not a.startswith("--") and ("r" in a or "R" in a)) or a == "--recursive" for a in args)
    return False

def check(cmd, depth=0):
    if depth > 4:
        return
    if CD_RE.search(cmd) and REC_RE.search(cmd):
        block()
    for m in SHELLC_RE.finditer(cmd):
        check(m.group(3), depth + 1)
    xsearch = False
    broad_seen = False
    for part in re.split(SPLIT, cmd):
        try:
            toks = shlex.split(part, posix=True)
        except ValueError:
            toks = part.split()
        toks = [t.lstrip("(") for t in toks]
        toks = [t for t in toks if t]
        while toks and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]) or toks[0] in ("sudo", "timeout", "nice", "command", "exec")):
            toks = toks[1:]
            if toks and re.match(r"^\d+[smh]?$", toks[0]):
                toks = toks[1:]
        is_xargs = bool(toks) and os.path.basename(toks[0]) == "xargs"
        if is_xargs:
            toks = toks[1:]
            while toks and toks[0].startswith("-"):
                flag = toks[0]
                toks = toks[1:]
                if flag in XARGS_VAL and toks:
                    toks = toks[1:]
        if not toks:
            continue
        prog = os.path.basename(toks[0])
        args = toks[1:]
        if is_xargs:
            if xargs_recursive(prog, args):
                xsearch = True
        elif any(is_broad(a) for a in toks[1:]):
            broad_seen = True
        if prog in SHELLS:
            for i, a in enumerate(args):
                if re.match(r"^-[A-Za-z]*c$", a) and i + 1 < len(args):
                    check(args[i + 1], depth + 1)
            continue
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
    if xsearch and broad_seen:
        block()

check(cmd)
sys.exit(0)
PY
