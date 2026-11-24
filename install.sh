#!/bin/bash
# Installs the claude-rc skill into ~/.claude/skills. Safe to run again.
# It never touches other skills. Files it would replace are first saved as NAME.bak-<time>.
set -u

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"    # fixed: the skill and claude_rc.sh refer to this path
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "== Checking what the sessions need"
need() { command -v "$1" >/dev/null 2>&1 && echo "  ok       $1" || { echo "  MISSING  $1  ($2)"; MISSING=1; }; }
MISSING=0
if command -v slurmx >/dev/null 2>&1; then
  echo "  ok       slurmx   (SUBMITTER=auto will submit with it)"
else
  need sbatch  "SLURM; claude-rc submits the session's job with it (slurmx not found)"
fi
need tmux    "each session runs inside tmux on the compute node"
need claude  "Claude Code; it must also be on the compute nodes' PATH (~/.local/bin or ~/.npm-global/bin) and logged in"
need flock   "the session registry is updated under a lock"
need awk     "registry editing"
[ "$MISSING" = 1 ] && echo "  Install the missing tools first (files are still copied below)."

backup_copy() {  # backup_copy <from> <to>
  if [ -e "$2" ] && ! cmp -s "$1" "$2"; then cp -p "$2" "$2.bak-$STAMP"; echo "  saved the old $(basename "$2") as $(basename "$2").bak-$STAMP"; fi
  cp -p "$1" "$2"
}

echo "== Copying files to $DEST"
mkdir -p "$DEST/claude-rc" "$DEST/scripts"
backup_copy "$SRC/claude-rc/SKILL.md"    "$DEST/claude-rc/SKILL.md"
backup_copy "$SRC/scripts/claude_rc.sh"  "$DEST/scripts/claude_rc.sh"
chmod +x "$DEST/scripts/claude_rc.sh"
echo "  claude-rc/SKILL.md, scripts/claude_rc.sh"

if [ -e "$DEST/config.sh" ]; then
  cp "$SRC/config.sh" "$DEST/config.sh.new"
  echo "  $DEST/config.sh already exists, so it was left alone."
  echo "  Check that it sets LAB_DIR, SESSIONS_DIR, REGISTRY, JOB_LOGS_DIR, CPU_JOB_LIMIT and HOST_JOB_TIME;"
  echo "  config.sh.new has the values claude-rc expects."
else
  cp "$SRC/config.sh" "$DEST/config.sh"
  echo "  config.sh (edit LAB_DIR, and anything else, to suit you)"
fi

echo "== Creating the session folders"
REGISTRY="$(. "$DEST/config.sh"; echo "$REGISTRY")"
SESSIONS_DIR="$(. "$DEST/config.sh"; echo "$SESSIONS_DIR")"
JOB_LOGS_DIR="$(. "$DEST/config.sh"; echo "$JOB_LOGS_DIR")"
if [ -z "$REGISTRY" ] || [ -z "$SESSIONS_DIR" ] || [ -z "$JOB_LOGS_DIR" ]; then
  echo "  config.sh doesn't set REGISTRY, SESSIONS_DIR and JOB_LOGS_DIR; fix it, then run this again."; exit 1
fi
mkdir -p "$SESSIONS_DIR" "$JOB_LOGS_DIR"
if [ ! -e "$REGISTRY" ]; then
  cat > "$REGISTRY" <<'EOF'
# Claude remote-control sessions

Kept by `claude_rc.sh` (the `claude-rc` skill): it adds a row once a session runs, or updates it on a resume. A session must be resumed from the same path and with the same name it was started with.

| Name | Path | Last job | Last started | Session id |
|------|------|----------|--------------|------------|
EOF
  echo "  created the registry $REGISTRY"
fi
echo "  sessions: $SESSIONS_DIR   job logs: $JOB_LOGS_DIR"

# With SKIP_PERMISSIONS=true, claude shows a one-time "bypass permissions" warning that waits
# for a keypress inside tmux. This setting skips it, so a new session starts on its own.
SKIP="$(. "$DEST/config.sh"; echo "${SKIP_PERMISSIONS:-true}")"
if [ "$SKIP" = true ]; then
  echo "== Skipping the one-time bypass-permissions warning"
  SETTINGS="$HOME/.claude/settings.json"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$SETTINGS" "$STAMP" <<'EOF'
import json, os, shutil, sys
p = sys.argv[1]
d = {}
if os.path.exists(p) and os.path.getsize(p) > 0:
    with open(p) as f:
        d = json.load(f)
if d.get("skipDangerousModePermissionPrompt") is True:
    print("  already set in " + p)
else:
    if os.path.exists(p):
        shutil.copy2(p, p + ".bak-" + sys.argv[2])
    d["skipDangerousModePermissionPrompt"] = True
    with open(p, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    print("  set skipDangerousModePermissionPrompt: true in " + p)
EOF
  else
    echo "  python3 not found: add  \"skipDangerousModePermissionPrompt\": true  to $SETTINGS yourself"
  fi
fi

echo "== Done"
echo "In Claude Code, ask for it in plain words, e.g.:"
echo "  start a claude session called my_rc in ~/my_project"
echo "or resume one:  resume my_rc"
echo "Read README.md first: sessions run without permission prompts."
