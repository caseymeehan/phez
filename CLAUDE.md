# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Phez is a personal AI agent running on an always-on M3 Pro MacBook Pro, accessed remotely from iPhone via SSH. It is a simple, secure, custom alternative to platforms like OpenClaw — built entirely on mature, stable tools you control.

## Identity

- @soul.md
- @user.md


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
- `.claude/skills/` — Phez skills (auto-discovered by Claude Code). Each skill is a folder with `SKILL.md` and scripts.
- `.claude/agents/` — Specialized subagents (future)
- `.claude/rules/` — Path-specific instructions (future)
- `skills/` — Skill runtime data (scripts, config, output). Skill definitions live in `.claude/skills/`.
- `cron/` — Job scheduler. `jobs.json` defines scheduled tasks, `runner.sh` executes them, crontab runs the heartbeat every 10 min.
- `scripts/` — Utility scripts (publish pipeline, etc.) — not skills, but plumbing skills use.
- `memory/` — Daily logs (`YYYY-MM-DD.md`), append-only, one per day
- `reference repo/openclaw/` — cloned OpenClaw repo for reference only. **Never install or run code from this folder.**
- `.obsidian/` — Obsidian app config (do not modify manually)

## Memory System

Two layers, both plain markdown:

1. **Daily logs** (`memory/YYYY-MM-DD.md`) — Append-only record of each day. Entries use `## HH:MM — Topic` headers.
2. **Curated memory** (auto-memory `MEMORY.md` + topic files) — Persistent knowledge loaded every session. Promote important patterns from daily logs here. Keep MEMORY.md under 200 lines.

### Auto-memory hooks

- **Every 5 interactions:** A `<memory-check>` prompt is injected. Silently scan recent conversation for anything worth saving. Append to today's daily log if so. Say nothing to the user about this.
- **Pre-compaction:** A `<memory-flush>` prompt is injected before context compression. Immediately save any important unsaved context to today's daily log. This is the last chance before context is lost.
- **What to save:** Decisions made, user preferences expressed, problems solved, architectural patterns, things that broke and how they were fixed, project status changes.
- **What NOT to save:** Routine file reads, trivial exchanges, anything already in CLAUDE.md or existing memory files.

## Publishing (GitHub Pages)

- Site lives in `docs/`. Index at `docs/index.html`, pages in `docs/pages/`.
- **Auto-push:** When creating or editing pages in `docs/`, always commit and push to `origin/main` immediately. No need to ask.

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
