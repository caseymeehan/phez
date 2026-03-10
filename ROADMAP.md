# Phez Roadmap

## Phase 1 — GitHub Pages Output System ✓
Quick win. Simple publish pipeline so Phez can post markdown as live webpages. Every future skill can output to the web.

- ✓ Publish script: markdown → HTML → `docs/` → auto-push
- ✓ Minimal template for clean output pages
- ✓ Index page lists all published outputs
- ✓ Live at https://caseymeehan.github.io/phez/

## Phase 2 — Skills System (starting with X) ✓
`skills/` folder with markdown instruction files. X/Twitter integration is the first skill — pull and analyze tweets using API key. Skills compose with each other.

- ✓ Skills folder convention (`skills/x/SKILL.md`) and CLAUDE.md documentation
- ✓ X skill: fetch 55 accounts, full pagination, complete storm capture
- ✓ 327 tweets fetched on first run, 54 threads enriched

## Phase 3 — Cron / Automation ✓
Scheduled tasks that trigger skills. Only makes sense once skills exist.

- ✓ `cron/jobs.json` registry (OpenClaw-inspired schema with state tracking)
- ✓ `cron/runner.sh` scheduler with lock file, logging, atomic state writes
- ✓ `launchd` plist running heartbeat every 10 minutes
- ✓ X fetch scheduled every 48 hours

## Phase 4 — Continuous Improvement
Phez regularly measures itself against the OpenClaw reference repo, identifies gaps, and suggests improvements. Memory stays pruned. Skills get refined.

- Self-review against OpenClaw patterns
- Memory pruning and curation
- Skill refinement based on usage
