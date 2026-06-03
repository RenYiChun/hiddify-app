# Sync Audits

This directory stores repository-backed audit snapshots for the weekly Hiddify full-module upstream sync.

Use these files as the portable record across machines and Codex environments. The local automation memory can still speed up reruns, but the files here are the durable source for prior audit conclusions, blockers, and next actions.

Files:
- `latest.md`: stable pointer to the most recent audit result
- `YYYY-MM-DD-hiddify-weekly-sync-audit.md`: immutable per-run snapshot
