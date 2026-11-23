#!/bin/bash
# Links the claude-rc and job-rc skills into ~/.claude/skills and prepares the folders.
# Run it from the clone, which should live at ~/.claude/claude-slurm (or set CLAUDE_SLURM_HOME).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${CLAUDE_SLURM_HOME:-$HOME/.claude/claude-slurm}"
if [ "$HERE" != "$(cd "$HOME_DIR" 2>/dev/null && pwd)" ]; then
  echo "This clone is at $HERE, but the scripts look in $HOME_DIR."
  echo "Move it there, or add  export CLAUDE_SLURM_HOME=$HERE  to your ~/.bashrc and rerun."
  exit 1
fi
chmod +x "$HERE"/scripts/*.sh
mkdir -p "$HOME/.claude/skills"
for s in claude-rc job-rc; do
  if [ -e "$HOME/.claude/skills/$s" ] && [ ! -L "$HOME/.claude/skills/$s" ]; then
    echo "Skipped $s: ~/.claude/skills/$s already exists and isn't a link"; continue
  fi
  ln -sfn "$HERE/skills/$s" "$HOME/.claude/skills/$s"
  echo "Linked ~/.claude/skills/$s"
done
. "$HERE/scripts/common.sh"
echo "Registry: $REGISTRY"
echo "Job logs: $JOB_LOGS_DIR"
command -v claude >/dev/null || echo "Warning: claude isn't on PATH here; install Claude Code first"
command -v tmux >/dev/null || echo "Warning: tmux isn't on PATH here"
echo "Done. Check the resources in $HERE/config.sh before the first job."
