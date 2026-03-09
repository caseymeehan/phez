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

- Root (`/Users/caseymeehan/Documents/Phez/`) — Obsidian vault, project notes, and CLAUDE.md
- `reference repo/openclaw/` — cloned OpenClaw repo for reference only. **Never install or run code from this folder.**
- `.obsidian/` — Obsidian app config (do not modify manually)

## Working Conventions

- Notes are Obsidian-flavored Markdown (wiki-links `[[note]]`, frontmatter supported)
- Memory and documentation live as markdown files in this vault
- When creating or editing notes, preserve existing frontmatter and wiki-link syntax
- The OpenClaw reference is for studying patterns (skills, memory, cron, channels) — not for copying wholesale

## Quick Start (from Termius on iPhone)

```bash
cd /Users/caseymeehan/Documents/Phez && (tmux new -s claude -d "claude" || tmux attach -t claude)
```

This launches Claude Code in the Phez folder, or reattaches to an existing session.
