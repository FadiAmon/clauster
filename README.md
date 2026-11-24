# claude-slurm

Run [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) sessions as SLURM jobs on a cluster and drive them from the Claude app or claude.ai with [remote control](https://docs.claude.com/en/docs/claude-code/remote-control). Each session runs in tmux on a compute node, has a name, and can be resumed later in the same folder.

It comes as two Claude Code skills, so you can just ask Claude ("start a session called `data-prep` in `~/proj/data`"), plus the scripts behind them, which also work on their own.

| Skill | What it does |
|---|---|
| `claude-rc` | Submits a new SLURM job that runs one session |
| `job-rc` | Starts another session inside the job you're already in, without a new job |

## Install

On the cluster's login node, with Claude Code and tmux installed and remote control working (`claude --remote-control` once by hand):

```bash
git clone https://github.com/FadiAmon/claude-slurm ~/.claude/claude-slurm
~/.claude/claude-slurm/install.sh
```

If you installed the older `claude-rc` bundle, the installer keeps your old skill folder as `claude-rc.bak-<time>`. To keep resuming your old sessions, point `REGISTRY` in `config.sh` at your old registry (`~/claude_sessions/claude_rc_sessions.md`); the format is the same.

Then set the job's time, CPUs, memory and partition in `~/.claude/claude-slurm/config.sh` to what your cluster allows. A session needs little: the model runs on Anthropic's servers.

## Use

Ask Claude, or run the scripts yourself:

```bash
S=~/.claude/claude-slurm/scripts

$S/submit.sh -n data-prep -d ~/proj/data      # new session in its own job
$S/submit.sh -r data-prep                     # resume it later, same folder
$S/submit.sh -n eval -d ~/proj -m opus -e high  # pick a model and effort

$S/job_rc.sh -n helper -d ~/proj               # from inside a job: one more session, no new job
```

The session shows up in the Claude app under its name. To use its terminal instead:

```bash
squeue -j <job> -h -o %N        # the node
ssh <node>
tmux attach -t claude_data-prep                    # claude-rc session
tmux -L job_<job> attach -t claude_helper          # job-rc session
```

The job ends when its sessions exit, at the time limit, or with `scancel <job>`.

## How it works

- `submit.sh` checks the name, then runs `sbatch` with the resources from `config.sh`. Logs go to `job_logs/slurm-<name>-<job>.out`.
- In the job, `claude_rc.sh` starts `claude --session-id <id> --remote-control <name>` in tmux and records the name, folder, job and session id in `sessions.md`. A resume runs `claude --resume <id>` from the same folder.
- One name, one session: a name already registered with another folder, or still queued or running, is refused.

## Permissions

By default a session asks before it runs commands or edits files, and you answer in the app. With `SKIP_PERMISSIONS=true` in `config.sh` every session runs with `--dangerously-skip-permissions` and never asks. That suits sessions nobody watches, but nothing then checks what they do, so turn it on only if you accept that.

## License

MIT
