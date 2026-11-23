#!/bin/bash
#SBATCH --job-name=claude
# The job submit.sh sends: starts a Claude Code remote-control session in a detached
# tmux session on the node, then keeps the job alive while any session runs in it.
# Submit it with submit.sh, which sets the job's name, folder, log and resources.
#
#   -n NAME   new session (default name: "Slurm Claude", not registered)
#   -r NAME   resume a registered session
#   -d DIR    working folder (default: the job's folder)
#   -m MODEL  -e EFFORT   passed to claude

. "${CLAUDE_SLURM_HOME:-$HOME/.claude/claude-slurm}/scripts/common.sh"

NAME="" RESUME="" WORKDIR="$PWD" MODEL="" EFFORT=""
while getopts "n:r:d:m:e:" opt; do
  case $opt in
    n) NAME="$OPTARG" ;; r) RESUME="$OPTARG" ;; d) WORKDIR="$OPTARG" ;;
    m) MODEL="$OPTARG" ;; e) EFFORT="$OPTARG" ;;
    *) echo "Usage: $0 [-n NAME | -r NAME] [-d DIR] [-m MODEL] [-e EFFORT]"; exit 1 ;;
  esac
done
check_effort "$EFFORT"

REG_NAME="${RESUME:-$NAME}"            # the name to register; none = not registered
NAME="${NAME:-${RESUME:-Slurm Claude}}"
JOBID="${SLURM_JOB_ID:-}"

# Never two sessions with one name: check again now that the job runs.
if [ -n "$REG_NAME" ]; then
  REG_PATH="$(reg_field "$REG_NAME" 3)"
  if [ -n "$REG_PATH" ] && [ "$REG_PATH" != "$WORKDIR" ]; then
    echo "ERROR: '$REG_NAME' is registered with path $REG_PATH, not $WORKDIR; not starting"; exit 1
  fi
  WHY="$(running_elsewhere "$REG_NAME" "$JOBID")"
  [ -n "$WHY" ] && { echo "ERROR: $WHY; not starting"; exit 1; }
fi

if [ -n "$RESUME" ]; then
  # remote-control names aren't conversation titles, so a session resumes by the id it started with
  SID="$(reg_field "$RESUME" 6)"
  [ -z "$SID" ] && { echo "ERROR: no session id registered for '$RESUME'"; exit 1; }
  CMD="$(claude_cmd resume "$RESUME" "$SID" "$MODEL" "$EFFORT")"
else
  SID="$(cat /proc/sys/kernel/random/uuid)"
  CMD="$(claude_cmd new "$NAME" "$SID" "$MODEL" "$EFFORT")"
fi

SESSION="$(tmux_name "$NAME")"
echo "Job: $JOBID  |  node: $(hostname -s)"
echo "tmux session: $SESSION  |  dir: $WORKDIR"
echo "Running: $CMD"

mkdir -p -m 700 "/tmp/tmux-$(id -u)"   # some nodes don't create tmux's socket folder
tmux kill-session -t "=$SESSION" 2>/dev/null
tmux new-session -d -s "$SESSION" -c "$WORKDIR" -e "CLAUDE_RC_NAME=$NAME" "$CMD"

sleep 5
if ! tmux has-session -t "=$SESSION" 2>/dev/null; then
  echo "ERROR: the session exited right after starting. To see why: cd $WORKDIR && $CMD"; exit 1
fi
if [ -n "$REG_NAME" ]; then
  register "$REG_NAME" "$WORKDIR" "$JOBID" "$SID"
else
  echo "Registry: not updated, no -n or -r name was given"
fi
echo "Attach: ssh $(hostname -s), then tmux attach -t $SESSION"

# Keep the job alive while this session or any job_rc.sh session in this job runs.
while tmux has-session -t "=$SESSION" 2>/dev/null \
   || { [ -n "$JOBID" ] && env -u TMUX tmux -L "job_$JOBID" ls >/dev/null 2>&1; }; do
  sleep 60
done
echo "All sessions in this job have ended"
