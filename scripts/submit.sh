#!/bin/bash
# Submit a SLURM job that runs a Claude Code remote-control session (claude_rc.sh).
#
#   submit.sh -n NAME -d DIR      start a new session called NAME in DIR
#   submit.sh -r NAME             resume NAME in the folder it was registered with
#   add -m MODEL and/or -e EFFORT to either (default: your ~/.claude/settings.json)
#
# Job time, CPUs, memory and partition come from config.sh.

. "${CLAUDE_SLURM_HOME:-$HOME/.claude/claude-slurm}/scripts/common.sh"

usage() { echo "Usage: $0 -n NAME -d DIR | -r NAME  [-m MODEL] [-e EFFORT]"; exit 1; }
NAME="" RESUME="" DIR="" MODEL="" EFFORT=""
while getopts "n:r:d:m:e:" opt; do
  case $opt in
    n) NAME="$OPTARG" ;; r) RESUME="$OPTARG" ;; d) DIR="$OPTARG" ;;
    m) MODEL="$OPTARG" ;; e) EFFORT="$OPTARG" ;; *) usage ;;
  esac
done
check_effort "$EFFORT"
if [ -n "$NAME" ] && [ -n "$RESUME" ]; then echo "ERROR: use -n or -r, not both"; exit 1; fi
N="${NAME:-$RESUME}"
[ -z "$N" ] && usage

REG="$(reg_field "$N" 3)"
if [ -n "$NAME" ]; then
  [ -z "$DIR" ] && { echo "ERROR: a new session needs -d DIR"; exit 1; }
  DIR="$(cd "$DIR" 2>/dev/null && pwd)" || { echo "ERROR: directory not found"; exit 1; }
  if [ -n "$REG" ] && [ "$REG" != "$DIR" ]; then
    echo "ERROR: '$N' is already registered with path $REG; resume it with -r or pick another name"; exit 1
  fi
  ARGS=(-n "$N" -d "$DIR")
else
  [ -z "$REG" ] && { echo "ERROR: '$N' is not registered (see $REGISTRY)"; exit 1; }
  [ -z "$(reg_field "$N" 6)" ] && { echo "ERROR: no session id registered for '$N'"; exit 1; }
  DIR="$REG"
  ARGS=(-r "$N")
fi
[ -d "$DIR" ] || { echo "ERROR: directory not found: $DIR"; exit 1; }
WHY="$(running_elsewhere "$N" "")"
[ -n "$WHY" ] && { echo "ERROR: $WHY"; exit 1; }
[ -n "$MODEL" ] && ARGS+=(-m "$MODEL")
[ -n "$EFFORT" ] && ARGS+=(-e "$EFFORT")

OPTS=(--parsable -J "$N" -D "$DIR" -o "$JOB_LOGS_DIR/slurm-%x-%j.out"
      --time "$JOB_TIME" --cpus-per-task "$JOB_CPUS" --mem "$JOB_MEM")
[ -n "$JOB_PARTITION" ] && OPTS+=(-p "$JOB_PARTITION")
# shellcheck disable=SC2206
[ -n "$SBATCH_EXTRA" ] && OPTS+=($SBATCH_EXTRA)

JOB="$(sbatch "${OPTS[@]}" "$CLAUDE_SLURM_HOME/scripts/claude_rc.sh" "${ARGS[@]}")" || exit 1
JOB="${JOB%%;*}"
echo "Submitted: $N  |  job: $JOB  |  dir: $DIR"
echo "Log: $JOB_LOGS_DIR/slurm-$N-$JOB.out"
echo "Node (empty while pending): squeue -j $JOB -h -o %N"
echo "Attach: ssh <node>, then tmux attach -t $(tmux_name "$N")"
