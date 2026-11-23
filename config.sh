# claude-slurm settings. Plain KEY="value" lines; $HOME and keys above may be used.
# The scripts read this file from $CLAUDE_SLURM_HOME (default ~/.claude/claude-slurm).

CLAUDE_SLURM_HOME="${CLAUDE_SLURM_HOME:-$HOME/.claude/claude-slurm}"

REGISTRY="$CLAUDE_SLURM_HOME/sessions.md"     # session names, folders and ids (one row each)
JOB_LOGS_DIR="$CLAUDE_SLURM_HOME/job_logs"     # SLURM logs of the session jobs

# Resources of a session job. A session needs little: Claude runs on Anthropic's servers.
JOB_TIME="7-00:00:00"                          # time limit (your cluster may allow less)
JOB_CPUS=2
JOB_MEM="8G"
JOB_PARTITION=""                               # empty = the cluster's default partition
SBATCH_EXTRA=""                                # anything else, e.g. "--account=mylab --qos=normal"

# true = every session runs with --dangerously-skip-permissions: it never asks before
# running a command or editing a file. Handy when nobody watches it, but nothing
# screens what it does. Leave false unless you accept that.
SKIP_PERMISSIONS=false
