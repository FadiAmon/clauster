# claude-rc

A Claude Code skill that starts (and resumes) a Claude session with Remote Control as a SLURM job on the cluster. The session runs inside tmux on a compute node, so you can open it from the Claude app and it keeps running after you disconnect.

## Install

```
CLAUSTER_DIR=~/clauster
git clone https://github.com/FadiAmon/clauster "$CLAUSTER_DIR"
cd "$CLAUSTER_DIR"
claude "Install this skill using ./install.sh"
```

## Use

Ask Claude in plain words, in any Claude Code session:

- "Start a claude session called `my_rc` in `~/my_project`."
- "Resume `my_rc`."
- "Start `my_rc` in `~/my_project` with opus at high effort."

You could also ask it to start a GPU job:

- "Start a GPU job named `gpu_rc` with rtx 4090."

## Files

| File | Role |
|---|---|
| `claude-rc/SKILL.md` | The skill Claude reads. |
| `scripts/claude_rc.sh` | The job script: starts claude in tmux, registers the session, keeps the job alive. |
| `config.sh` | Folders and limits (`LAB_DIR`, `SESSIONS_DIR`, `REGISTRY`, `JOB_LOGS_DIR`, `CPU_JOB_LIMIT`, `HOST_JOB_TIME`, `SUBMITTER`, `DEFAULT_MODEL`, `DEFAULT_EFFORT`, `QOS`, `PARTITION`, `ACCOUNT`, `SKIP_PERMISSIONS`). |
| `install.sh` | Copies everything into `~/.claude/skills/` and creates the folders. |
