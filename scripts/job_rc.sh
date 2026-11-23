#!/bin/bash
# Start or resume a Claude Code remote-control session in a new tmux session INSIDE
# the current SLURM job, without submitting a new job. Run it from a shell inside a
# job, e.g. a session started with submit.sh.
#
#   job_rc.sh -n NAME -d DIR    new session
#   job_rc.sh -r NAME           resume, in its registered folder
#   add -m MODEL and/or -e EFFORT to either
#
# The job gets its own tmux server (socket job_<jobid>), so these sessions end with
# the job. Attach: ssh <node>, then tmux -L job_<jobid> attach -t <session>

. "${CLAUDE_SLURM_HOME:-$HOME/.claude/claude-slurm}/scripts/common.sh"

NAME="" RESUME="" WORKDIR="" MODEL="" EFFORT=""
while getopts "n:r:d:m:e:" opt; do
  case $opt in
    n) NAME="$OPTARG" ;; r) RESUME="$OPTARG" ;; d) WORKDIR="$OPTARG" ;;
    m) MODEL="$OPTARG" ;; e) EFFORT="$OPTARG" ;;
    *) echo "Usage: $0 -n NAME -d DIR | -r NAME  [-m MODEL] [-e EFFORT]"; exit 1 ;;
  esac
done
check_effort "$EFFORT"
if [ -n "$NAME" ] && [ -n "$RESUME" ]; then echo "ERROR: use -n or -r, not both"; exit 1; fi
if [ -z "$NAME" ] && [ -z "$RESUME" ]; then echo "ERROR: give -n NAME (new) or -r NAME (resume)"; exit 1; fi
N="${NAME:-$RESUME}"

# The job this shell really runs in, from its cgroup: inside tmux, $SLURM_JOB_ID can
# belong to another job on the same node.
JOBID="$(grep -o 'job_[0-9]*' /proc/self/cgroup | head -1 | cut -d_ -f2)"
JOBID="${JOBID:-$SLURM_JOB_ID}"
[ -z "$JOBID" ] && { echo "ERROR: not inside a SLURM job; use submit.sh instead"; exit 1; }

WHY="$(running_elsewhere "$N" "$JOBID")"
[ -n "$WHY" ] && { echo "ERROR: $WHY"; exit 1; }

REG="$(reg_field "$N" 3)"
if [ -n "$NAME" ]; then
  [ -z "$WORKDIR" ] && { echo "ERROR: a new session needs -d DIR"; exit 1; }
  WORKDIR="$(cd "$WORKDIR" 2>/dev/null && pwd)" || { echo "ERROR: directory not found"; exit 1; }
  if [ -n "$REG" ] && [ "$REG" != "$WORKDIR" ]; then
    echo "ERROR: '$N' is already registered with path $REG"; exit 1
  fi
  SID="$(cat /proc/sys/kernel/random/uuid)"
  CMD="$(claude_cmd new "$N" "$SID" "$MODEL" "$EFFORT")"
else
  WORKDIR="${REG:-$WORKDIR}"
  [ -z "$WORKDIR" ] && { echo "ERROR: '$N' is not registered"; exit 1; }
  SID="$(reg_field "$N" 6)"
  [ -z "$SID" ] && { echo "ERROR: no session id registered for '$N'"; exit 1; }
  CMD="$(claude_cmd resume "$N" "$SID" "$MODEL" "$EFFORT")"
fi
[ -d "$WORKDIR" ] || { echo "ERROR: directory not found: $WORKDIR"; exit 1; }

SESSION="$(tmux_name "$N")"
SOCK="job_$JOBID"
mkdir -p -m 700 "/tmp/tmux-$(id -u)"
if env -u TMUX tmux -L "$SOCK" has-session -t "=$SESSION" 2>/dev/null; then
  echo "ERROR: tmux session $SESSION already runs in job $JOBID"; exit 1
fi

env -u TMUX tmux -L "$SOCK" new-session -d -s "$SESSION" -c "$WORKDIR" \
  -e "CLAUDE_RC_NAME=$N" -e "SLURM_JOB_ID=$JOBID" -e "SLURM_JOBID=$JOBID" "$CMD"

sleep 5
if ! env -u TMUX tmux -L "$SOCK" has-session -t "=$SESSION" 2>/dev/null; then
  echo "ERROR: the session exited right after starting. To see why: cd $WORKDIR && $CMD"; exit 1
fi
register "$N" "$WORKDIR" "$JOBID" "$SID"

NODE="$(hostname -s)"
echo "Started: $N  |  job: $JOBID (no new job)  |  node: $NODE"
echo "tmux session: $SESSION  |  socket: $SOCK  |  dir: $WORKDIR"
echo "Running: $CMD"
echo "Attach: ssh $NODE, then tmux -L $SOCK attach -t $SESSION"
