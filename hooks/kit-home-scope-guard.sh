#!/bin/bash
# Blocks file searches across the whole home folder or the whole disk.
# Such searches trigger macOS permission prompts (iCloud Drive, Music, Photos)
# and walk into personal folders. Exit 2 = block; the message goes back to Claude.
command -v python3 >/dev/null 2>&1 || { echo "Blocked: kit guard needs python3. Install Apple's command line tools." >&2; exit 2; }
read -r -d '' PY <<'PY' || true
import json, os, re, shlex, sys

HOME = os.path.expanduser("~").rstrip("/")
BROAD = {"~", "~/", "$HOME", "$HOME/", "${HOME}", "${HOME}/", HOME, HOME + "/",
         "/", "/Users", "/Users/", "/System/Volumes/Data", "/System/Volumes/Data/"}
SEARCHERS = {"find", "mdfind", "grep", "egrep", "fgrep", "rg", "ag", "ack", "fd", "fdfind",
             "locate", "tree", "du"}
MSG = ("Blocked: no searches across your whole home folder or disk. "
       "Search inside the project or vault folder instead.")

def tokenize(s):
    # shlex is slow on very large strings (a big file write), so use a plain split there
    if len(s) > 20000:
        return re.findall(r"[^\s'\"]+", s)
    try:
        return shlex.split(s, posix=True)
    except ValueError:
        return s.split()

def block():
    print(MSG, file=sys.stderr)
    sys.exit(2)

def norm(tok):
    return tok.strip().strip("'\"")

def is_broad(tok):
    t = norm(tok)
    return t in BROAD or t in {"~/*", HOME + "/*", "/*", "/Users/*"} or bool(re.fullmatch(r"/Users/[^/]+/?", t))

try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)
tool = data.get("tool_name", "")
ti = data.get("tool_input") or {}
if not isinstance(ti, dict):
    ti = {}

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
PREFIXES = {"sudo", "timeout", "nice", "command", "exec", "env", "time", "nohup", "caffeinate"}
OPT_PREFIXES = {"env", "time", "nohup", "caffeinate"}
GREPS = {"grep", "egrep", "fgrep"}
PATTERN_SEARCHERS = GREPS | {"rg", "ag", "ack"}
# short options that take a value, per program
SHORT_VAL = {"grep": "efmABCdD", "egrep": "efmABCdD", "fgrep": "efmABCdD",
             "rg": "efgtTmABCjMErd", "ag": "GgpmABC", "ack": "ABCm"}
LONG_VAL = {"regexp", "file", "max-count", "after-context", "before-context", "context",
            "include", "exclude", "exclude-dir", "exclude-from", "directories", "devices",
            "label", "binary-files", "glob", "type", "type-not", "max-depth", "threads",
            "replace", "ignore-file", "max-columns", "encoding"}

home_forms = r"(?:~/?|\$HOME/?|\$\{HOME\}/?|" + re.escape(HOME) + r"/?|/)"
CD_RE = re.compile(r"(^|[;&|\s])cd(?:\s+([\"']?)" + home_forms + r"\2)?\s*(?=;|&|\||\n|$)")
REC_RE = re.compile(r"(^|[;&|\s])(find\s+\.|grep\s+-[A-Za-z]*[rR]|rg\s|fd\s|ag\s|tree(\s|$)|du\s)")

SHELLC_RE = re.compile(r"\b(bash|sh|zsh|dash|ksh)\s+-[A-Za-z]*c\s+(['\"])(.*?)\2")
EVAL_RE = re.compile(r"\beval\s+(['\"])(.*?)\1")

def parse_search_args(prog, args):
    """Return (positionals, has_pattern_option, recursive) for grep-like programs."""
    valchars = SHORT_VAL.get(prog, "")
    pos, has_e, rec = [], False, False
    i = 0
    while i < len(args):
        a = args[i]
        i += 1
        if a == "--":
            pos.extend(args[i:])
            break
        if a.startswith("--"):
            name, eq, _val = a[2:].partition("=")
            if name in ("recursive", "dereference-recursive"):
                rec = True
            if name == "directories" and _val == "recurse":
                rec = True
            if name in ("regexp", "file"):
                has_e = True
            if name in LONG_VAL and not eq and i < len(args):
                if name == "directories" and args[i] == "recurse":
                    rec = True
                i += 1
            continue
        if a.startswith("-") and len(a) > 1:
            for j, ch in enumerate(a[1:], 1):
                if ch in "rR":
                    rec = True
                if ch in valchars:
                    if ch in "ef" and prog in PATTERN_SEARCHERS - {"ag", "ack"}:
                        has_e = True
                    rest = a[j + 1:]
                    if not rest and i < len(args):
                        rest = args[i]
                        i += 1
                    if ch == "d" and rest == "recurse":
                        rec = True
                    break
            continue
        pos.append(a)
    return pos, has_e, rec

def find_paths(args):
    """Only the start paths of find: skip leading options, stop at the first expression."""
    out = []
    i = 0
    while i < len(args):
        a = args[i]
        if re.fullmatch(r"-[HLPEXdsx]+|-O\d", a):
            i += 1
        elif a == "-D" or a == "-f":
            if a == "-f" and i + 1 < len(args):
                out.append(args[i + 1])
            i += 2
        elif a.startswith("-") or a.startswith("(") or a == "!":
            break
        else:
            out.append(a)
            i += 1
    return out

def search_paths(prog, args):
    """The arguments that count as places to search. Patterns and expressions are not places."""
    if prog == "find":
        return find_paths(args), True
    if prog in PATTERN_SEARCHERS:
        pos, has_e, rec = parse_search_args(prog, args)
        if not has_e and pos:
            pos = pos[1:]
        return pos, (rec if prog in GREPS else True)
    return list(args), True

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
    for m in EVAL_RE.finditer(cmd):
        check(m.group(2), depth + 1)
    xsearch = False
    broad_seen = False
    for part in re.split(SPLIT, cmd):
        toks = tokenize(part)
        toks = [t.lstrip("(") for t in toks]
        toks = [t for t in toks if t]
        while toks and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]) or os.path.basename(toks[0]) in PREFIXES):
            word = os.path.basename(toks[0])
            toks = toks[1:]
            if word in OPT_PREFIXES:
                while toks and toks[0].startswith("-"):
                    flag = toks[0]
                    toks = toks[1:]
                    if flag in ("-u", "-t", "-w") and toks:
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
        if prog == "eval":
            check(" ".join(args), depth + 1)
            continue
        paths, counts = search_paths(prog, args)
        if is_xargs:
            if xargs_recursive(prog, args):
                xsearch = True
        elif any(is_broad(a) for a in paths):
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
        if prog in SEARCHERS and counts and any(is_broad(a) for a in paths):
            block()
    if xsearch and broad_seen:
        block()

try:
    check(cmd)
except SystemExit:
    raise
except Exception:
    print("Blocked: the kit guard hit an unexpected error.", file=sys.stderr)
    sys.exit(2)
sys.exit(0)
PY
# The tool input goes to python on stdin (no size limit). Any unexpected failure blocks.
python3 -I -c "$PY"
rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "Blocked: the kit guard hit an unexpected error." >&2
  exit 2
fi
exit "$rc"
