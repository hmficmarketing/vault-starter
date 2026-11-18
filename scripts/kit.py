#!/usr/bin/env python3
"""Vault Starter Kit installer core. Standard library only. Run with: python3 -I kit.py"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

BEGIN = "<!-- vault-starter:begin -->"
END = "<!-- vault-starter:end -->"
TIERS_RE = re.compile(r"<!-- kit:tiers -->.*?<!-- /kit:tiers -->\n?", re.S)
TOKENS = ("NAME", "VAULT_PATH", "APPS_LIST", "DATE")


def encode_project_dir(path):
    return re.sub(r"[^A-Za-z0-9]", "-", str(path))


def render(text, values):
    """Substitute only the four uppercase placeholders. Lowercase ones are left alone."""
    for key in TOKENS:
        if key in values:
            text = text.replace("{{" + key + "}}", str(values[key]))
    return text


def apps_list(apps):
    return "\n".join("- " + a for a in apps)


def backup(path):
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = Path(str(path) + ".bak-vault-starter-" + stamp)
    n = 1
    while dest.exists():
        dest = Path(str(path) + ".bak-vault-starter-" + stamp + "-" + str(n))
        n += 1
    shutil.copy2(path, dest)
    return dest


def copy_vault(template, vault, values):
    template, vault = Path(template), Path(vault)
    created = []
    vault.mkdir(parents=True, exist_ok=True)
    for src in sorted(template.rglob("*")):
        rel = src.relative_to(template)
        dest = vault / rel
        if src.is_dir():
            dest.mkdir(parents=True, exist_ok=True)
            continue
        if dest.exists() or dest.is_symlink():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        data = src.read_bytes()
        try:
            data = render(data.decode("utf-8"), values).encode("utf-8")
        except UnicodeDecodeError:
            pass
        dest.write_bytes(data)
        created.append(str(dest))
    return created


def merge_section(claude_md, section):
    """Put section between the kit markers. Text outside the markers is untouched."""
    claude_md = Path(claude_md)
    block = BEGIN + "\n" + section.strip("\n") + "\n" + END
    if not claude_md.exists():
        claude_md.parent.mkdir(parents=True, exist_ok=True)
        claude_md.write_text(block + "\n", encoding="utf-8")
        return
    old = claude_md.read_text(encoding="utf-8")
    nb, ne = old.count(BEGIN), old.count(END)
    b, e = old.find(BEGIN), old.find(END)
    if not ((nb == 0 and ne == 0) or (nb == 1 and ne == 1 and b < e)):
        raise SystemExit(
            "Your ~/.claude/CLAUDE.md has a broken vault-starter section "
            "(a begin or end marker is missing or doubled). "
            "Fix the markers, then run setup again.")
    if nb == 1:
        new = old[:b] + block + old[e + len(END):]
    else:
        sep = "" if not old else ("\n" if old.endswith("\n") else "\n\n")
        if old and not old.endswith("\n\n") and old.endswith("\n"):
            sep = "\n"
        new = old + sep + block + "\n"
    if new == old:
        return
    backup(claude_md)
    claude_md.write_text(new, encoding="utf-8")


def link_memory(vault):
    vault = Path(os.path.abspath(str(vault)))
    target = vault / ".claude" / "memory"
    target.mkdir(parents=True, exist_ok=True)
    link = Path.home() / ".claude" / "projects" / encode_project_dir(vault) / "memory"
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.is_symlink():
        if os.path.realpath(link) == os.path.realpath(target):
            return
        raise SystemExit(
            "vault-starter: %s already points to %s, not to %s. "
            "Not changing it, so nothing is lost. Move or remove it yourself, then run setup again."
            % (link, os.path.realpath(link), os.path.realpath(target)))
    elif link.is_dir():
        for item in sorted(link.iterdir()):
            dest = target / item.name
            if dest.exists() or dest.is_symlink():
                dest = target / (item.name + ".from-claude.md")
                n = 1
                while dest.exists():
                    dest = target / (item.name + ".from-claude-" + str(n) + ".md")
                    n += 1
            shutil.move(str(item), str(dest))
        link.rmdir()
    elif link.exists():
        raise SystemExit("vault-starter: %s exists and is not a folder; not touching it" % link)
    os.symlink(str(target), str(link))


def _bullet_name(line):
    m = re.match(r"^\s*[-*]\s+(.*\S)\s*$", line)
    return m.group(1) if m else None


def write_router(code_dir, apps, template=None, values=None):
    code_dir = Path(code_dir)
    code_dir.mkdir(parents=True, exist_ok=True)
    path = code_dir / "CLAUDE.md"
    if not path.exists():
        if template is None:
            raise SystemExit("vault-starter: router template is required to create %s" % path)
        text = Path(template).read_text(encoding="utf-8")
        vals = dict(values or {})
        vals["APPS_LIST"] = apps_list(apps)
        path.write_text(render(text, vals), encoding="utf-8")
        return
    old = path.read_text(encoding="utf-8")
    lines = old.split("\n")
    start = next((i for i, l in enumerate(lines) if l.strip() == "## Apps"), None)
    if start is None:
        listed = set()
        missing = list(apps)
        if not missing:
            return
        new = old.rstrip("\n") + "\n\n## Apps\n\n" + apps_list(missing) + "\n"
    else:
        end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
        listed = {_bullet_name(l) for l in lines[start + 1:end]} - {None}
        missing = [a for a in apps if a not in listed]
        if not missing:
            return
        # insert after the last bullet in the section, else right after the heading
        last = start
        for i in range(start + 1, end):
            if _bullet_name(lines[i]) is not None:
                last = i
        if last == start:
            ins = ["", ] + ["- " + a for a in missing]
            lines[start + 1:start + 1] = ins
        else:
            lines[last + 1:last + 1] = ["- " + a for a in missing]
        new = "\n".join(lines)
    if new == old:
        return
    backup(path)
    path.write_text(new, encoding="utf-8")


def git_init(vault, name):
    vault = str(vault)
    if os.path.isdir(os.path.join(vault, ".git")):
        return

    def run(*args):
        return subprocess.run(["git", "-C", vault] + list(args), capture_output=True, text=True)

    def cfg(key):
        return run("config", key).stdout.strip()

    run("init")
    run("add", "-A")
    ident = []
    if not (cfg("user.name") and cfg("user.email")):
        ident = ["-c", "user.name=" + name, "-c", "user.email=vault@localhost"]
    r = subprocess.run(["git", "-C", vault] + ident + ["commit", "-m", "Start vault"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("vault-starter: git commit failed: " + (r.stderr or r.stdout).strip(), file=sys.stderr)


def split_apps(raw):
    return [a.strip() for a in (raw or "").split(",") if a.strip()]


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _load_manifest(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def install_assets(kit, home):
    """Copy kit skills and hooks into ~/.claude. Never overwrite a file the person edited."""
    kit, home = Path(kit), Path(home)
    pairs = []
    for src in sorted((kit / "skills").glob("kit-*/SKILL.md")):
        pairs.append((src, home / ".claude" / "skills" / src.parent.name / "SKILL.md"))
    for src in sorted((kit / "hooks").glob("kit-*.sh")):
        pairs.append((src, home / ".claude" / "hooks" / src.name))
    mpath = home / ".claude" / "vault-starter" / "manifest.json"
    manifest = _load_manifest(mpath)
    old = dict(manifest)
    result = {"installed": [], "updated": [], "kept_user_edit": []}
    for src, dest in pairs:
        key = str(dest)
        new_hash = _sha(src)
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dest)
            result["installed"].append(key)
            manifest[key] = new_hash
        else:
            cur = _sha(dest)
            if cur == new_hash:
                manifest[key] = new_hash
            elif manifest.get(key) == cur:
                shutil.copyfile(src, dest)
                result["updated"].append(key)
                manifest[key] = new_hash
            elif manifest.get(key) == new_hash:
                # Person edited it and the kit copy did not change: nothing new to offer.
                stale = Path(key + ".kit-new")
                if stale.exists():
                    stale.unlink()
                continue
            else:
                shutil.copyfile(src, key + ".kit-new")
                result["kept_user_edit"].append(key)
                continue
        if dest.suffix == ".sh":
            os.chmod(dest, 0o755)
    if manifest != old:
        mpath.parent.mkdir(parents=True, exist_ok=True)
        mpath.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def write_privacy(folders):
    path = Path.home() / ".claude" / "vault-starter" / "privacy-folders.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    text = "".join(f + "\n" for f in folders)
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_text(text, encoding="utf-8")


def read_privacy_file():
    path = Path.home() / ".claude" / "vault-starter" / "privacy-folders.txt"
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return None
    return [l.strip() for l in lines if l.strip() and not l.strip().startswith("#")]


def _same_folder(a, b):
    return a.rstrip("/") == b.rstrip("/")


def add_privacy(existing, new):
    """Return the folders in new that are not already in existing (no duplicates)."""
    out = []
    for f in new:
        if not any(_same_folder(f, e) for e in list(existing) + out):
            out.append(f)
    return out


def append_privacy(folders):
    """Append folders to the list file. Keeps everything already in it, comments included."""
    if not folders:
        return
    path = Path.home() / ".claude" / "vault-starter" / "privacy-folders.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    old = path.read_text(encoding="utf-8") if path.exists() else ""
    if old and not old.endswith("\n"):
        old += "\n"
    path.write_text(old + "".join(f + "\n" for f in folders), encoding="utf-8")


def register_hooks(settings, hook_paths):
    settings = Path(settings)
    bad = SystemExit("Your ~/.claude/settings.json isn't valid JSON, so I left it alone. "
                     "Fix it, then run setup again.")
    existed = settings.exists()
    raw = settings.read_text(encoding="utf-8") if existed else ""
    if raw.strip():
        try:
            data = json.loads(raw)
        except ValueError:
            raise bad
    else:
        data = {}
    if not isinstance(data, dict):
        raise bad
    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        raise bad
    entries = hooks.get("PreToolUse", [])
    if not isinstance(entries, list):
        raise bad
    existing = []
    for e in entries:
        if isinstance(e, dict) and isinstance(e.get("hooks"), list):
            existing += [h.get("command", "") for h in e["hooks"] if isinstance(h, dict)]
    existing = [c for c in existing if isinstance(c, str)]
    added = False
    for hp in hook_paths:
        hp = str(Path(hp).absolute())
        cmd = 'bash "' + hp + '"'
        if any(c == cmd or hp in c for c in existing):
            continue
        entries.append({"matcher": ".*", "hooks": [{"type": "command", "command": cmd}]})
        existing.append(cmd)
        added = True
    if not added:
        return
    hooks["PreToolUse"] = entries
    data["hooks"] = hooks
    if existed and raw.strip():
        backup(settings)
    settings.parent.mkdir(parents=True, exist_ok=True)
    settings.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def install(args):
    kit = Path(args.kit_dir)
    home = Path.home()
    vault = Path(os.path.abspath(os.path.expanduser(args.vault)))
    apps = split_apps(args.apps)
    values = {
        "NAME": args.name,
        "VAULT_PATH": str(vault),
        "APPS_LIST": apps_list(apps),
        "DATE": datetime.now().strftime("%Y-%m-%d"),
    }
    copy_vault(kit / "template" / "vault", vault, values)

    section = (kit / "template" / "global" / "kit-section.md").read_text(encoding="utf-8")
    if args.no_tiers:
        section = TIERS_RE.sub("", section)
    merge_section(home / ".claude" / "CLAUDE.md", render(section, values))

    link_memory(vault)
    ans = home / ".claude" / "vault-starter" / "answers.json"
    try:
        prev_answers = json.loads(ans.read_text(encoding="utf-8"))
        if not isinstance(prev_answers, dict):
            prev_answers = {}
    except Exception:
        prev_answers = {}
    if args.code_dir:
        code_dir = Path(os.path.abspath(os.path.expanduser(args.code_dir)))
    elif isinstance(prev_answers.get("code_dir"), str) and prev_answers["code_dir"]:
        code_dir = Path(prev_answers["code_dir"])
    else:
        code_dir = home / "Code"
    write_router(code_dir, apps, template=kit / "template" / "code-router" / "CLAUDE.md", values=values)

    if args.privacy is not None:
        privacy = [p.strip() for p in args.privacy.split(";") if p.strip()]
    else:
        # The list file is the source of truth, so answers.json never drifts from it.
        privacy = read_privacy_file()
        if privacy is None:
            prev = prev_answers.get("privacy", [])
            privacy = prev if isinstance(prev, list) else []
    added = []
    if args.privacy_add:
        wanted = [p.strip() for p in args.privacy_add.split(";") if p.strip()]
        added = add_privacy(privacy, wanted)
        privacy = privacy + added
    answers = {
        "name": args.name,
        "vault": str(vault),
        "apps": apps,
        "privacy": privacy,
        "no_tiers": bool(args.no_tiers),
        "git": bool(args.git),
        "code_dir": str(code_dir),
    }
    ans.parent.mkdir(parents=True, exist_ok=True)
    ans.write_text(json.dumps(answers, indent=2) + "\n", encoding="utf-8")

    if args.git:
        git_init(vault, args.name)

    res = install_assets(kit, home)
    if args.privacy is not None or not (home / ".claude" / "vault-starter" / "privacy-folders.txt").exists():
        write_privacy(privacy)
    elif added:
        append_privacy(added)
    register_hooks(home / ".claude" / "settings.json",
                   [home / ".claude" / "hooks" / "kit-home-scope-guard.sh",
                    home / ".claude" / "hooks" / "kit-privacy-guard.sh"])
    for dest in res["kept_user_edit"]:
        print("You changed %s, so I kept your version. The new one is at %s.kit-new." % (dest, dest))


def main(argv=None):
    p = argparse.ArgumentParser(prog="kit.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("encode")
    e.add_argument("path")
    i = sub.add_parser("install")
    i.add_argument("--vault", required=True)
    i.add_argument("--name", required=True)
    i.add_argument("--apps", default="")
    i.add_argument("--privacy", default=None)
    i.add_argument("--privacy-add", default=None)
    i.add_argument("--code-dir", default=None)
    i.add_argument("--no-tiers", action="store_true")
    i.add_argument("--git", action="store_true")
    i.add_argument("--kit-dir", default=str(Path(__file__).resolve().parent.parent))
    args = p.parse_args(argv)
    if args.cmd == "encode":
        print(encode_project_dir(args.path))
    else:
        install(args)


if __name__ == "__main__":
    main()
