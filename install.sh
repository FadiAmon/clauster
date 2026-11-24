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
STAMP="$(date +%Y%m%d-%H%M%S)"
chmod +x "$HERE"/scripts/*.sh
mkdir -p "$HOME/.claude/skills"
for s in claude-rc job-rc; do
  if [ -e "$HOME/.claude/skills/$s" ] && [ ! -L "$HOME/.claude/skills/$s" ]; then
    # e.g. an older claude-rc bundle: keep it as a backup, then link this one
    mv "$HOME/.claude/skills/$s" "$HOME/.claude/skills/$s.bak-$STAMP"
    echo "Moved the existing ~/.claude/skills/$s to $s.bak-$STAMP"
  fi
  ln -sfn "$HERE/skills/$s" "$HOME/.claude/skills/$s"
  echo "Linked ~/.claude/skills/$s"
done
. "$HERE/scripts/common.sh"
echo "Registry: $REGISTRY"
echo "Job logs: $JOB_LOGS_DIR"
for t in claude tmux sbatch squeue flock awk; do
  command -v "$t" >/dev/null || echo "Warning: $t isn't on PATH here; the sessions need it"
done
echo "claude must also be on the compute nodes' PATH (~/.local/bin or ~/.npm-global/bin) and logged in."
echo "Done. Check the resources in $HERE/config.sh before the first job."
