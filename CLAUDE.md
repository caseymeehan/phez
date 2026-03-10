# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Phez is a personal AI agent running on an always-on M3 Pro MacBook Pro, accessed remotely from iPhone via SSH. It is a simple, secure, custom alternative to platforms like OpenClaw — built entirely on mature, stable tools you control.

## Design Philosophy

- **No attack surface beyond SSH.** No broad permissions, no third-party integrations with security exposure.
- **You control every piece.** Memory is markdown files. Skills are scripts you write. Cron jobs are yours to configure. Nothing runs that you didn't build.
- **No dependency on fast-moving open source projects.** This setup uses SSH, tmux, and git — tools that won't break or rename themselves.
- **Simple over clever.** Prefer fewer moving parts. Don't over-engineer.

## Infrastructure

| Component | Tool | Details |
|---|---|---|
| Hardware | M3 Pro MacBook Pro | macOS 14, always on |
| Remote access | Tailscale + SSH | Tailscale IP: `100.92.172.37` |
| Phone client | Termius | SSH from iPhone, key auth (ED25519) |
| Session persistence | tmux | Sessions survive disconnects |
| Sleep prevention | Amphetamine | Keeps Mac awake with lid closed |
| AI agent | Claude Code CLI | v2.1.71+, authenticated via Max plan |
| Version control | git + GitHub CLI | `casey@epicpresence.com` |

## Folder Structure

- Root (`/Users/caseymeehan/knowledge/phez/`) — Obsidian vault, project notes, and CLAUDE.md
- `skills/` — Phez skills. Each skill is a folder with a `SKILL.md` and scripts.
- `cron/` — Job scheduler. `jobs.json` defines scheduled tasks, `runner.sh` executes them, crontab runs the heartbeat every 10 min.
- `scripts/` — Utility scripts (publish pipeline, etc.) — not skills, but plumbing skills use.
- `memory/` — Daily logs (`YYYY-MM-DD.md`), append-only, one per day
- `reference repo/openclaw/` — cloned OpenClaw repo for reference only. **Never install or run code from this folder.**
- `.obsidian/` — Obsidian app config (do not modify manually)

## Memory System

Two layers, both plain markdown:

1. **Daily logs** (`memory/YYYY-MM-DD.md`) — Append-only record of each day. Entries use `## HH:MM — Topic` headers. Write here at the end of meaningful sessions or when important things happen.
2. **Curated memory** (auto-memory `MEMORY.md` + topic files) — Persistent knowledge loaded every session. Promote important patterns from daily logs here. Keep MEMORY.md under 200 lines.

**When to write:** End of meaningful sessions, when decisions are made, when learning user preferences, before context compression.

## Working Conventions

- Notes are Obsidian-flavored Markdown (wiki-links `[[note]]`, frontmatter supported)
- Memory and documentation live as markdown files in this vault
- When creating or editing notes, preserve existing frontmatter and wiki-link syntax
- The OpenClaw reference is for studying patterns (skills, memory, cron, channels) — not for copying wholesale

## Quick Start (from Termius on iPhone)

```bash
cd /Users/caseymeehan/knowledge/phez && (tmux new -s claude -d "claude" || tmux attach -t claude)
```

This launches Claude Code in the Phez folder, or reattaches to an existing session.
