#!/bin/bash
#SLX --vram 0 --time 7-00:00:00
#SBATCH --time=7-00:00:00
# A CPU job submitted with slurmx or sbatch (SUBMITTER in config.sh). Each reads only its own
# header line above. Cores and memory are the defaults of slurmx or the cluster.

# Usage (from the session's directory D; the job is named after the session; T and J are HOST_JOB_TIME
# and JOB_LOGS_DIR in ~/.claude/skills/config.sh, and the header's --time is the fallback):
#   slurmx submit --no-wait --time T -j NAME -w D -o J ~/.claude/skills/scripts/claude_rc.sh -n NAME -d D   # new, slurmx
#   sbatch --time T -J NAME -D D -o J/slurm-%x-%j.out ~/.claude/skills/scripts/claude_rc.sh -n NAME -d D    # new, sbatch
#   (resume: -r NAME instead of -n NAME -d D)
#
# -n  remote-control display name for a NEW session (default: "Slurm Claude")
# -r  name or ID of an existing Claude session to resume (runs plain `claude --resume`)
# -d  working directory (default: submit directory)
# -m  model: an alias such as fable, opus, sonnet, haiku, or a full model name (default: settings.json)
# -e  effort: low, medium, high, xhigh or max (default: settings.json)

NAME=""
RESUME=""
WORKDIR="$PWD"   # slurmx -w D or sbatch -D D starts the job in D
MODEL=""
EFFORT=""

while getopts "n:r:d:m:e:" opt; do
  case $opt in
    n) NAME="$OPTARG" ;;
    r) RESUME="$OPTARG" ;;
    d) WORKDIR="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    e) EFFORT="$OPTARG" ;;
    *) echo "Usage: slurmx submit [options] $0 (or sbatch [options] $0) [-n name] [-r resume_name] [-d dir] [-m model] [-e effort]"; exit 1 ;;
  esac
done

# defaults from config.sh when -m / -e aren't given (empty there = ~/.claude/settings.json)
[ -z "$MODEL" ] && MODEL="$(. "$HOME/.claude/skills/config.sh"; echo "$DEFAULT_MODEL")"
[ -z "$EFFORT" ] && EFFORT="$(. "$HOME/.claude/skills/config.sh"; echo "$DEFAULT_EFFORT")"

case "$EFFORT" in
  ""|low|medium|high|xhigh|max) ;;
  *) echo "ERROR: effort must be low, medium, high, xhigh or max"; exit 1 ;;
esac

# the name the app shows: an emoji for the role tag, then the name (WRK.ct.seal -> "🟢 WRK.ct.seal").
# Only the app shows the emoji; the registry, tmux, logs and $CLAUDE_RC_NAME use the plain name.
display_name() {
  case "$1" in
    MON.*) echo "🟣 $1" ;;
    WRK.*) echo "🟢 $1" ;;
    *) echo "$1" ;;
  esac
}

# the name to register: the resumed name, else the -n name (none: not registered)
REG_NAME="${RESUME:-$NAME}"

# default tmux/display name: the resumed name if given, else a generic one
NAME="${NAME:-${RESUME:-Slurm Claude}}"

REGISTRY="$(. "$HOME/.claude/skills/config.sh"; echo "$REGISTRY")"   # from the skills' settings
reg_field() {  # reg_field <name> <column>: 3 = path, 4 = last job
  awk -F'|' -v n="$1" -v c="$2" '{ a=$2; b=$c; gsub(/^ +| +$/, "", a); gsub(/^ +| +$/, "", b) } a==n { print b; exit }' "$REGISTRY"
}

# Never run two sessions with the same name: stop before starting claude if the
# name belongs to another path, or a session with this name is already running.
if [ -n "$REG_NAME" ]; then
  REG_PATH="$(reg_field "$REG_NAME" 3)"
  REG_JOB="$(reg_field "$REG_NAME" 4)"
  if [ -n "$REG_PATH" ] && [ "$REG_PATH" != "$WORKDIR" ]; then
    echo "ERROR: '$REG_NAME' is registered with path $REG_PATH, not $WORKDIR; not starting"; exit 1
  fi
  if [ -n "$REG_JOB" ] && [ "$REG_JOB" != "$SLURM_JOB_ID" ] && [ -n "$(squeue -h -t R -j "$REG_JOB" 2>/dev/null)" ]; then
    echo "ERROR: '$REG_NAME' is registered as running in job $REG_JOB, which is still running; stop it first or pick another name"; exit 1
  fi
  if squeue --me -h -t R -n "$REG_NAME" -o %i | grep -qv "^${SLURM_JOB_ID}\$"; then
    echo "ERROR: another running job is named '$REG_NAME'; stop it first or pick another name"; exit 1
  fi
fi

# rename the Slurm job to match the Claude session name

# tmux session names can't contain spaces, dots or colons
SESSION="$(echo "claude_${NAME}" | tr -c 'A-Za-z0-9_-' '_')"

echo "SLURM_JOBID=$SLURM_JOBID"
echo "SLURM_JOB_NODELIST=$SLURM_JOB_NODELIST"
echo "tmux session: $SESSION  |  dir: $WORKDIR"

# Make sure claude is on PATH (adjust if you installed it elsewhere)
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

if [ -n "$RESUME" ]; then
  # remote-control names aren't saved as conversation titles, so a session is resumed by its id:
  # the id given with --session-id at start and kept in the registry's Session id column
  SID="$(reg_field "$RESUME" 6)"
  if [ -z "$SID" ] && [[ "$RESUME" =~ ^[0-9a-f-]{36}$ ]]; then SID="$RESUME"; fi
  if [ -z "$SID" ]; then echo "ERROR: no session id registered for '$RESUME', so it can't be resumed"; exit 1; fi
  CMD="claude --resume $SID --remote-control '$(display_name "$RESUME")'"
else
  SID="$(cat /proc/sys/kernel/random/uuid)"
  CMD="claude --session-id $SID --remote-control '$(display_name "$NAME")'"
fi
[ -n "$MODEL" ] && CMD="$CMD --model $(printf %q "$MODEL")"
[ -n "$EFFORT" ] && CMD="$CMD --effort $EFFORT"
# SKIP_PERMISSIONS in config.sh: true = no permission prompts (the default)
SKIP_PERMISSIONS="$(. "$HOME/.claude/skills/config.sh"; echo "${SKIP_PERMISSIONS:-true}")"
[ "$SKIP_PERMISSIONS" = true ] && CMD="$CMD --dangerously-skip-permissions"
echo "Running: $CMD"

# some nodes fail to create tmux's socket dir on their own
mkdir -p -m 700 "/tmp/tmux-$(id -u)"
tmux kill-session -t "$SESSION" 2>/dev/null
tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CMD"

# Register the session once it runs, same rules as job_rc.sh: add a row for a new
# name, or update Last job and Last started for a name registered with this path.
reg_path() {
  awk -F'|' -v n="$1" '{ a=$2; b=$3; gsub(/^ +| +$/, "", a); gsub(/^ +| +$/, "", b) } a==n { print b; exit }' "$REGISTRY"
}
sleep 5
if ! tmux has-session -t "=$SESSION" 2>/dev/null; then
  echo "Registry: not updated, the claude session exited right after starting"
elif [ -z "$REG_NAME" ]; then
  echo "Registry: not updated, no -n or -r name was given"
else
  DATE="$(date +%F)"
  (
    flock -x 9
    REG="$(reg_path "$REG_NAME")"
    if [ -z "$REG" ]; then
      printf '| %s | %s | %s | %s | %s |\n' "$REG_NAME" "$WORKDIR" "$SLURM_JOB_ID" "$DATE" "$SID" >> "$REGISTRY"
      echo "Registry: added $REG_NAME"
    elif [ "$REG" = "$WORKDIR" ]; then
      awk -F'|' -v n="$REG_NAME" -v j="$SLURM_JOB_ID" -v d="$DATE" -v s="$SID" 'BEGIN { OFS="|" }
        { a=$2; gsub(/^ +| +$/, "", a) }
        a==n { $4=" " j " "; $5=" " d " "; if (s != "") $6=" " s " "; $7="" }
        { print }' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
      echo "Registry: updated $REG_NAME"
    else
      echo "Registry: not updated, '$REG_NAME' is registered with path $REG, not $WORKDIR"
    fi
  ) 9>>"$REGISTRY.lock"
fi

### Keeps the job alive until the time limit ###
# The job must not end while the session runs: SLURM kills the tmux session with the job.
# Where the cluster has an anaconda module with jupyter, a notebook server does the waiting (as in the
# original script; its link appears in the job log). Anywhere else, a plain sleep does the same.
if command -v module >/dev/null 2>&1 && module load anaconda 2>/dev/null && command -v jupyter >/dev/null 2>&1; then
  source activate cuda_env 2>/dev/null   # optional; the base environment's jupyter is enough
  jupyter notebook
else
  echo "No anaconda module or jupyter here; keeping the job alive with sleep until the time limit"
  sleep infinity
fi
