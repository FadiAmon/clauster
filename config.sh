# Settings for the claude-rc skill. Read by scripts/claude_rc.sh and by the skill.
# Keep the syntax plain: KEY="value", referring only to $HOME or keys above it.

## Folders
LAB_DIR="$HOME"                                  # where your projects live; claude-rc searches it for a session's folder (set it to your projects folder)
SESSIONS_DIR="$HOME/claude_sessions"             # everything claude-rc keeps, in one folder
REGISTRY="$SESSIONS_DIR/claude_rc_sessions.md"   # session names, paths and ids (a session is resumed from here)
JOB_LOGS_DIR="$SESSIONS_DIR/job_logs"            # SLURM logs of the host jobs

## Cluster
CPU_JOB_LIMIT=24                                 # when a session starts another one on its own: keep your CPU jobs (running and pending) below this
HOST_JOB_TIME="7-00:00:00"                       # time limit of a host job; the session ends with it
SUBMITTER="auto"                                 # how jobs are submitted: auto (slurmx if it's installed, else sbatch), slurmx or sbatch

## sbatch only (slurmx picks these itself)
QOS=""                                           # QoS for the job; empty = the cluster's default
PARTITION=""                                     # partition for the job; empty = the cluster's default
ACCOUNT=""                                       # account for the job; empty = your default account

## Permissions
SKIP_PERMISSIONS=true                            # true: sessions run with --dangerously-skip-permissions and never ask before running a command; false: they ask, and you answer in the app
