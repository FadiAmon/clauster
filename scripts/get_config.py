#!/usr/bin/env python3
"""Print the skills' settings from ~/.claude/skills/config.sh, filled in for one session.

Usage: get_config.py [-p PROJECT] [-n NAME] [--init] [KEY]
  -p  the project path the session works on
  -n  the session name
  --init  (with -p and -n) create the session's LOGS_DIR and start LOGS_DIR/.paths with the
      project path; the session adds the output folders it creates
  KEY  print only that value
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
CONFIG = os.path.join(os.path.dirname(HERE), "config.sh")
LINE_RE = re.compile(r'^\s*([A-Z_][A-Z0-9_]*)=(?:"([^"]*)"|(\S*))')
VAR_RE = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?")


def parse(path, known):
    out = {}
    with open(path) as f:
        for line in f:
            m = LINE_RE.match(line)
            if m:
                k, v = m.group(1), m.group(2) if m.group(2) is not None else m.group(3)
                env = {**os.environ, **known, **out}
                out[k] = VAR_RE.sub(lambda x: env.get(x.group(1), x.group(0)), v)
    return out


def project_name(name, project):
    m = re.match(r"^(?:MON|WRK)\.([^.]+)", name or "")
    if m:
        return m.group(1)
    return os.path.basename(os.path.realpath(project)) if project else (name or "{project_name}")


def load(project=None, name=None):
    cfg = parse(CONFIG, {})
    fill = {"{name}": name,
            "{project_name}": project_name(name, project) if (name or project) else None}
    for k, v in cfg.items():
        for ph, val in fill.items():
            if val:
                v = v.replace(ph, val)
        cfg[k] = v
    return cfg


def init(cfg, project):
    logs = cfg["LOGS_DIR"]
    os.makedirs(logs, exist_ok=True)
    paths = os.path.join(logs, ".paths")
    have = open(paths).read().splitlines() if os.path.exists(paths) else []
    line = f"project={os.path.realpath(project)}"
    if line not in have:
        with open(paths, "a") as f:
            f.write(line + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-p", "--project")
    ap.add_argument("-n", "--name")
    ap.add_argument("--init", action="store_true")
    ap.add_argument("key", nargs="?")
    a = ap.parse_args()
    cfg = load(a.project, a.name)
    if a.init:
        if not (a.project and a.name):
            sys.exit("ERROR: --init needs -p PROJECT and -n NAME")
        init(cfg, a.project)
    if a.key:
        if a.key not in cfg:
            sys.exit(f"ERROR: no setting {a.key}")
        print(cfg[a.key])
    else:
        for k, v in cfg.items():
            print(f"{k}={v}")


if __name__ == "__main__":
    main()
