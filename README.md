# claude-rc

A Claude Code skill that starts (and resumes) a Claude session with Remote Control as a SLURM job on the cluster. The session runs inside tmux on a compute node, so you can open it from the Claude app and it keeps running after you disconnect.

## What you need first

This bundle is the skill and its scripts. It does not include the tools below; they must already work on your account:

| Needed | Why |
|---|---|
| SLURM on the cluster | The job is submitted with `sbatch`. |
| `tmux` and `claude` on the compute nodes | The job starts `claude` inside tmux. `claude` must be logged in and on the node's PATH (`~/.local/bin` or `~/.npm-global/bin`). |
| `flock`, `awk` | Updating the session registry. |
| Remote Control available on your Claude account | Needed to open the session from the app. |

It works on SLURM clusters. On another scheduler it will not work as is.

## Install

```
unzip claude-rc-bundle.zip
cd claude-rc-bundle
./install.sh
```

It copies the skill to `~/.claude/skills/` (the path is fixed), creates the session folders, and checks the tools above. It saves any file it replaces as `<name>.bak-<time>`. An existing `config.sh` is left alone and `config.sh.new` is written next to it.

Then edit `~/.claude/skills/config.sh`: set `LAB_DIR` to the folder where your projects live. The other values work as they are.

## Use

Ask Claude in plain words, in any Claude Code session:

- "Start a claude session called `my_rc` in `~/my_project`."
- "Resume `my_rc`."
- "Start `my_rc` in `~/my_project` with opus at high effort."

It submits a CPU job (no GPU), prints the job id and how to attach (`ssh <node>`, then `tmux attach -t claude_<name>_`), and records the session in the registry so a later resume uses the same name and folder. The session appears in the Claude app under its name.

## Things to know

- **No permission prompts by default.** With `SKIP_PERMISSIONS=true` in `config.sh` (the default), every session starts with `--dangerously-skip-permissions`: it never asks before running a command, and nothing screens its commands. Set it to `false` to get prompts, which you answer in the app.
- **It holds a CPU slot until its time limit** (`HOST_JOB_TIME`, 7 days by default). Cancel the job to end the session.
- **Resume needs the registry.** `~/claude_sessions/claude_rc_sessions.md` (set by `REGISTRY`) holds each session's name, folder, last job and id. A session can only be resumed from the same folder and name. Don't delete its row.
- **Names are unique.** Starting a name that already runs, or that is registered with another folder, is refused.
- **Keep-alive.** The job must stay up or SLURM kills the session. The script runs a Jupyter notebook server for that where an `anaconda` module exists (its link appears in the job log), and otherwise just sleeps.

## Files

| File | Role |
|---|---|
| `claude-rc/SKILL.md` | The skill Claude reads. |
| `scripts/claude_rc.sh` | The job script: starts claude in tmux, registers the session, keeps the job alive. |
| `config.sh` | Folders and limits (`LAB_DIR`, `SESSIONS_DIR`, `REGISTRY`, `JOB_LOGS_DIR`, `CPU_JOB_LIMIT`, `HOST_JOB_TIME`). |
| `install.sh` | Copies everything into `~/.claude/skills/` and creates the folders. |
