# claude-rc

A Claude Code skill that starts (and resumes) a Claude session with Remote Control as a SLURM job on the cluster. The session runs inside tmux on a compute node, so you can open it from the Claude app and it keeps running after you disconnect.

## Install

```
git clone https://github.com/FadiAmon/claude-slurm
cd claude-slurm
./install.sh
```

It copies the skill to `~/.claude/skills/` (the path is fixed), creates the session folders, and checks the tools it needs (`sbatch`, `tmux`, `claude`, `flock`, `awk`). It saves any file it replaces as `<name>.bak-<time>`. An existing `config.sh` is left alone and `config.sh.new` is written next to it.

Then edit `~/.claude/skills/config.sh`: set `LAB_DIR` to the folder where your projects live. The other values work as they are.

## Use

Ask Claude in plain words, in any Claude Code session:

- "Start a claude session called `my_rc` in `~/my_project`."
- "Resume `my_rc`."
- "Start `my_rc` in `~/my_project` with opus at high effort."

It submits a CPU job (no GPU), prints the job id and how to attach (`ssh <node>`, then `tmux attach -t claude_<name>_`), and records the session in the registry so a later resume uses the same name and folder. The session appears in the Claude app under its name.

## Files

| File | Role |
|---|---|
| `claude-rc/SKILL.md` | The skill Claude reads. |
| `scripts/claude_rc.sh` | The job script: starts claude in tmux, registers the session, keeps the job alive. |
| `config.sh` | Folders and limits (`LAB_DIR`, `SESSIONS_DIR`, `REGISTRY`, `JOB_LOGS_DIR`, `CPU_JOB_LIMIT`, `HOST_JOB_TIME`, `SKIP_PERMISSIONS`). |
| `install.sh` | Copies everything into `~/.claude/skills/` and creates the folders. |
