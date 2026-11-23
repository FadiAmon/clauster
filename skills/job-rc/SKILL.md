---
name: job-rc
description: Starts or resumes a Claude Code remote-control session in a new tmux session inside the current SLURM job, without submitting a new job, by running ~/.claude/claude-slurm/scripts/job_rc.sh. Same naming and registry as claude-rc, but the session shares the caller's job, which saves job slots. Use when the user asks to start or resume a session inside the current job.
---

# job-rc

Runs `~/.claude/claude-slurm/scripts/job_rc.sh`. It starts `claude --remote-control` in a new detached tmux session on this node, inside the job this session already runs in. It submits no job.

Use it only from a session that runs inside a SLURM job, such as one started by claude-rc. Outside a job the script stops with an error; use claude-rc then.

## How it differs from claude-rc

- **No new job**: the session lives and dies with the current job. Each one can be resumed later, with either skill.
- **Shared resources**: the sessions share the job's CPUs and memory. Run heavy work as separate SLURM jobs.
- **Own tmux server per job**: socket `job_<jobid>`. Attach with `ssh <node>`, then `tmux -L job_<jobid> attach -t <session>`.
- **Own name**: the session can read its name with `echo $CLAUDE_RC_NAME`.

## Commands

| Task | Command |
|------|---------|
| new session X in folder D | `~/.claude/claude-slurm/scripts/job_rc.sh -n "X" -d D` |
| resume session X | `~/.claude/claude-slurm/scripts/job_rc.sh -r "X"` |
| either, with model M and effort E | add `-m M -e E` |

- Model and effort only when the user names them (`-m opus|sonnet|haiku|<full name>`, `-e low|medium|high|xhigh|max`).
- New session: D is the folder the session's task lives in. Expand `~` yourself and always pass `-d` and a name.
- Resume: the script uses the registered folder.

## Steps

1. Run the command. It waits 5 seconds and checks that the session still runs.
2. On `ERROR`, report the message. Don't fall back to claude-rc without saying so: that submits a new job.
3. On success it prints the name, job, node, tmux session and attach command. Report them.

To stop a session: `tmux -L job_<jobid> kill-session -t <session>`, only when the user asks.
