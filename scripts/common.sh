# Shared by submit.sh, claude_rc.sh and job_rc.sh. Sourced, not run.

CLAUDE_SLURM_HOME="${CLAUDE_SLURM_HOME:-$HOME/.claude/claude-slurm}"
if [ ! -f "$CLAUDE_SLURM_HOME/config.sh" ]; then
  echo "ERROR: $CLAUDE_SLURM_HOME/config.sh not found; clone claude-slurm there or set CLAUDE_SLURM_HOME"; exit 1
fi
. "$CLAUDE_SLURM_HOME/config.sh"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"   # where claude is usually installed

mkdir -p "$JOB_LOGS_DIR"
if [ ! -s "$REGISTRY" ]; then
  printf '| Name | Path | Last job | Last started | Session id |\n|---|---|---|---|---|\n' > "$REGISTRY"
fi

# reg_field <name> <column>: 3 = path, 4 = last job, 5 = last started, 6 = session id
reg_field() {
  awk -F'|' -v n="$1" -v c="$2" '{ a=$2; b=$c; gsub(/^ +| +$/, "", a); gsub(/^ +| +$/, "", b) } a==n { print b; exit }' "$REGISTRY"
}

# tmux session names can't contain spaces, dots or colons
tmux_name() { echo "claude_$1" | tr -c 'A-Za-z0-9_-' '_'; }

check_effort() {
  case "$1" in
    ""|low|medium|high|xhigh|max) ;;
    *) echo "ERROR: effort must be low, medium, high, xhigh or max"; exit 1 ;;
  esac
}

# running_elsewhere <name> <this job id>: prints why the name can't start, if it can't.
# A name is taken when its registered job still runs (in another job) or another
# running job of yours carries the name.
running_elsewhere() {
  local job
  job="$(reg_field "$1" 4)"
  if [ -n "$job" ] && [ "$job" != "$2" ] && [ -n "$(squeue -h -t R,PD -j "$job" 2>/dev/null)" ]; then
    echo "'$1' is registered as running in job $job, which is still queued or running"; return
  fi
  if squeue --me -h -t R,PD -n "$1" -o %i 2>/dev/null | grep -v "^${2}\$" | grep -q .; then
    echo "another job of yours is named '$1'"
  fi
}

# claude_cmd <new|resume> <name> <session id> <model> <effort>
claude_cmd() {
  local cmd
  if [ "$1" = new ]; then
    cmd="claude --session-id $3 --remote-control $(printf %q "$2")"
  else
    cmd="claude --resume $3 --remote-control $(printf %q "$2")"
  fi
  [ -n "$4" ] && cmd="$cmd --model $(printf %q "$4")"
  [ -n "$5" ] && cmd="$cmd --effort $5"
  [ "$SKIP_PERMISSIONS" = true ] && cmd="$cmd --dangerously-skip-permissions"
  echo "$cmd"
}

# register <name> <path> <job id> <session id>: add a row, or update the row of a
# name registered with the same path. Runs under a lock: several jobs share the file.
register() {
  (
    flock -x 9
    local reg date
    reg="$(reg_field "$1" 3)"
    date="$(date +%F)"
    if [ -z "$reg" ]; then
      printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$date" "$4" >> "$REGISTRY"
      echo "Registry: added $1"
    elif [ "$reg" = "$2" ]; then
      awk -F'|' -v n="$1" -v j="$3" -v d="$date" -v s="$4" 'BEGIN { OFS="|" }
        { a=$2; gsub(/^ +| +$/, "", a) }
        a==n { $4=" " j " "; $5=" " d " "; $6=" " s " " }
        { print }' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
      echo "Registry: updated $1"
    else
      echo "Registry: not updated, '$1' is registered with path $reg, not $2"
    fi
  ) 9>>"$REGISTRY.lock"
}
