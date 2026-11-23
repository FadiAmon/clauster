---
name: claude-rc
description: Starts or resumes a Claude Code remote-control session as its own SLURM job, in a tmux session on the node, by running ~/.claude/claude-slurm/scripts/submit.sh. Keeps a registry of session names and folders so a resume uses the same ones. Use when the user asks to launch, start, open or resume a Claude session on the cluster.
---

# claude-rc

Runs `~/.claude/claude-slurm/scripts/submit.sh`, which submits a SLURM job (`claude_rc.sh`). The job starts `claude --remote-control` in a detached tmux session on its node and stays alive while the session runs, so the user can drive it from the Claude app or claude.ai. The job's time, CPUs, memory and partition come from `~/.claude/claude-slurm/config.sh`; don't add resources of your own.

## Session registry

`REGISTRY` in `config.sh` (default `~/.claude/claude-slurm/sessions.md`) is a table with one row per session: Name, Path, Last job, Last started, Session id. A session can only be resumed by its name, in the folder it started in, so the registry is the source of truth for a resume. The scripts write it themselves once a session runs; never edit it yourself, and never delete a row unless the user asks.

**Never two sessions with one name.** `submit.sh` refuses a name registered with another folder, a name whose registered job is still queued or running, and a name another job of the user already carries. The job checks again when it starts.

## Commands

| User says | Command |
|-----------|---------|
| new session called X in folder D | `~/.claude/claude-slurm/scripts/submit.sh -n "X" -d D` |
| resume session X | `~/.claude/claude-slurm/scripts/submit.sh -r "X"` |
| either, with model M and effort E | add `-m M -e E` |

- Model and effort only when the user names them. `-m` takes an alias (`opus`, `sonnet`, `haiku`) or a full model name; `-e` takes `low`, `medium`, `high`, `xhigh` or `max`. Without them the session uses `~/.claude/settings.json`.
- New session: D is the folder the session will work in. Expand `~` yourself. If the user gave no folder, use the registered path when the name is registered, else ask which folder. Don't invent a name.
- Resume: the script uses the registered folder; don't pass `-d`. If the user's text matches exactly one registered name, use it and say so; if several, list them and ask.

## Steps

1. Run the command. On `ERROR`, report the message; don't work around it.
2. It prints the job id and log path. Get the node with `squeue -j <job> -h -o "%T %N"`; the node is empty while the job is pending, so say so.
3. Once the job runs, check its log for `Registry: added` or `Registry: updated`, and for `ERROR`.
4. Report: job id, state, node, and how to attach.

Attach: `ssh <node>`, then `tmux attach -t <session>`. The tmux session is `claude_` plus the name with every character outside `A-Za-z0-9_-` replaced by `_`; the log shows it on the `tmux session:` line.

## Notes

- A new session runs `claude --session-id <new id> --remote-control "X"`; a resume runs `claude --resume <registered id> --remote-control "X"`, because remote-control names aren't saved as conversation titles.
- `SKIP_PERMISSIONS=true` in `config.sh` adds `--dangerously-skip-permissions`: the session then never asks before running commands. It's off by default; change it only when the user asks.
- The job ends by itself when the session (and any `job-rc` session in the same job) exits, or at the time limit.
- To stop a session: `scancel <job id>`, only when the user asks.
