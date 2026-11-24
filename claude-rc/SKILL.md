---
name: claude-rc
description: Starts or resumes a Claude Code remote-control session as a SLURM job on the cluster, in a tmux session on the node, by submitting ~/.claude/skills/scripts/claude_rc.sh with sbatch as a CPU job. Keeps a registry of session names and paths so a resume uses the same ones. Use when the user asks to launch, start, open or resume a Claude session on the cluster, or to run claude_rc.
---

# claude-rc

Submits `~/.claude/skills/scripts/claude_rc.sh` with `sbatch`, as a CPU job (time limit `HOST_JOB_TIME`; cores and memory are the cluster's defaults; never add a GPU to it: a session needs none). The script starts `claude` inside a detached tmux session on the node, then keeps the job alive.

Settings come from `~/.claude/skills/config.sh` (print one with `. ~/.claude/skills/config.sh; echo "$REGISTRY"`), and a name in capitals below (`REGISTRY`, `HOST_JOB_TIME`, `JOB_LOGS_DIR`, `LAB_DIR`, `CPU_JOB_LIMIT`) means its value there.

## Session registry

`REGISTRY` is a table with one row per session: Name, Path, Last job, Last started, Session id.

A session can only be resumed from the same path and with the same name it was started with, so the registry is the source of truth for a resume. Name and Path are stored exactly as passed to the script. Never delete a row unless the user asks: a cancelled session can still be resumed.

**Never two sessions with one name.** Before submitting, check that the name isn't running already, with `squeue --me`: no running job carries the name, and the name's Last job in the registry isn't running. If it runs, stop and tell the user. The script enforces the same when the job starts: it exits before starting claude if the name is registered with a different path, if its registered Last job is still running, or if another running job carries the name.

`claude_rc.sh` writes the registry itself, under a file lock, once the job has started and the session runs: it adds a row for a new name, or updates Last job and Last started for a name registered with the same path. A name registered with a different path is left unchanged. A session started without `-n` or `-r` isn't registered. While the job is pending, its row doesn't exist yet.

## Map the user's words to the command

| User says | Command |
|-----------|---------|
| new session called X in directory D | `cd D && sbatch --time <HOST_JOB_TIME> -J "X" -D D -o <JOB_LOGS_DIR>/slurm-%x-%j.out ~/.claude/skills/scripts/claude_rc.sh -n "X" -d D` |
| resume session X | `cd P && sbatch --time <HOST_JOB_TIME> -J "X" -D P -o <JOB_LOGS_DIR>/slurm-%x-%j.out ~/.claude/skills/scripts/claude_rc.sh -r "X"`, where P is X's registered path |
| either, with model M and effort E | add `-m M -e E` |

- Model and effort: only when the user names them. `-m` takes an alias (`fable`, `opus`, `sonnet`, `haiku`) or a full model name; `-e` takes `low`, `medium`, `high`, `xhigh` or `max`. Without them the session gets the defaults in `~/.claude/settings.json` (Sonnet 5.5 at xhigh).

- `-J` names the job after the session, `-D` starts it in the session's folder and `-o` puts its log in `JOB_LOGS_DIR`. Options for sbatch go before the script; the script's own options go after it.
- New session: D is the session's working repo, and you submit from D itself. Expand `~` in D yourself. No directory given: find the working repo from the name first (step 2). Use the current directory only if no repo is found. Always pass `-d`. No name given: omit `-n` (the script uses "Slurm Claude"); don't invent a name.
- Resume: submit from the registered path itself, with `-D` set to it and `-r` only. Don't pass `-d`: the script then uses the folder the job starts in, which is the session's path.
- Don't combine `-r` and `-n`.

## Steps

1. Check the user's jobs with `squeue --me`, so you can report the total. When the user asked for the session, there is no job limit: the job limits cover only jobs a session decides to run itself. If a session uses claude-rc on its own, the limit applies: submit only if the user's CPU jobs stay below `CPU_JOB_LIMIT`.
2. Check the registry:
   - **New session:** if the name is already registered with a different path than the one the user gave, stop and tell the user. If the name is registered and no directory was given, use the registered path. Otherwise, if no directory was given, find the working repo from the name before submitting anything. Look in this order and stop at the first source that gives one clear answer:
     1. Session history: `cd ~/.claude/projects; grep -l "<name>" ./*/*.jsonl`, then read the repo from the file's `"cwd"` value (`grep -m1 -o '"cwd":"[^"]*"' <file>`). Use `./*/` because project folder names start with `-`. Ignore hits whose cwd is `LAB_DIR` itself: those are conversations that only mention the name.
     2. Old logs: the line `tmux session: ... | dir: ...` in `slurm-<name>-*.out` (or older `claude_rc-*.out`) files for that name (in `JOB_LOGS_DIR`, `LAB_DIR` and candidate repos).
     3. Folder names: strip a trailing `_rc` from the name and `find LAB_DIR -maxdepth 5 -type d -iname "*<stem>*"`. Several hits under one project usually mean the repo is the parent folder; check before choosing.
     Confirm the chosen folder exists with `ls -d`. Tell the user which folder you chose and which source gave it, then submit. If sources disagree, stop and ask the user for the directory; don't guess. If nothing is found, use the current directory (`pwd`) and say so.
   - **Resume:** use the registered Name and Path exactly. If the user's text isn't an exact name but matches one registered name, use that one and say so. If it matches several, list them and ask. If it matches none (for example a session started by hand), ask the user for the directory; don't guess. If the user gives a different directory than the registered one, tell them and use the registered one.
3. Submit with the command from the table above. Logs: both write `slurm-<name>-<jobid>.out` in `JOB_LOGS_DIR`. Where jupyter is available, the log also shows the job's Jupyter link (`https://<node>...:<port>/tree?token=...`).
4. sbatch prints the job id. Don't edit the registry yourself: the script does it when the job starts. After the job starts, check the `Registry: ...` line in its log.
5. Get the state and node with `squeue -j <jobid> -h -o "%T %N"`. The node is empty while the job is pending; say so.
6. Report: job id, state, node, and how to attach.

Attach: `ssh <node>` then `tmux attach -t <session>`. The session name is `claude_` plus the name with every character outside `A-Za-z0-9_-` replaced by `_`. A trailing `_` is normal. The log shows it on the line `tmux session: ...`.

## Known behavior

- The job carries the session name from the start (`-J`).
- With `SKIP_PERMISSIONS=true` in `config.sh` (the default), every session runs with `--dangerously-skip-permissions`: it never asks for permission, and nothing screens its commands. With `false` it asks, and the user answers in the app. Change it only when the user asks.
- A new session runs `claude --session-id <new id> --remote-control "X"` inside tmux, and the script stores the id in the registry. A resume runs `claude --resume <registered id> --remote-control "X"`, because remote-control names aren't saved as conversation titles; a name without a registered id can't be resumed. Both add any `-m`/`-e` flags, and `--dangerously-skip-permissions` when `SKIP_PERMISSIONS=true`.
- A name starting with `MON.` or `WRK.` shows in the app with 🟣 or 🟢 before it. Pass the plain name. A resumed session reconnects to its own entry in the app (tested with `job-rc`).
- At its end the script keeps the job alive until the time limit, because SLURM kills the tmux session when the job ends. On a cluster with an anaconda module and jupyter it starts a notebook server for this (its link is in the log, and a `cuda_env` "EnvironmentNameNotFound" line there is harmless); anywhere else it just sleeps. Don't remove this wait.
- To stop a session: cancel its job with `scancel <id>`, only when the user asks.
