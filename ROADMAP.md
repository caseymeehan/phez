# Phez Roadmap

## Phase 1 — GitHub Pages Output System
Quick win. Simple publish pipeline so Phez can post markdown as live webpages. Every future skill can output to the web.

- Publish script: markdown → HTML → `docs/` → auto-push
- Minimal template for clean output pages
- Index page lists all published outputs

## Phase 2 — Skills System (starting with X)
`skills/` folder with markdown instruction files. X/Twitter integration is the first skill — pull and analyze tweets using API key. Skills compose with each other.

- Skills folder convention and CLAUDE.md documentation
- X skill: fetch tweets, analyze, output as markdown or publish to web
- Skills are just markdown instructions + shell scripts

## Phase 3 — Cron / Automation
Scheduled tasks that trigger skills. Only makes sense once skills exist.

- `cron/` folder with launchd plists
- Schedule X analysis and other skills to run automatically
- Manual trigger option from Termius

## Phase 4 — Continuous Improvement
Phez regularly measures itself against the OpenClaw reference repo, identifies gaps, and suggests improvements. Memory stays pruned. Skills get refined.

- Self-review against OpenClaw patterns
- Memory pruning and curation
- Skill refinement based on usage
