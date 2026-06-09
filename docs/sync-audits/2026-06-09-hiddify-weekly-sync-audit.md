# Hiddify Weekly Sync Audit - 2026-06-09

Workspace: `D:\github.com\hiddify-app`

Mode: catch-up policy with conservative integration gate (`docs/sync-audits/sync-policy.md`)

## Summary

- Re-read the repo-backed policy and last catch-up snapshot, then re-inventoried the full recursive tree.
- Fetched `--all --prune --tags` for the root repo and every discovered recursive submodule.
- No module was updated this run. The tree is clean, but the only new upstream movement sits on branch-based modules with large or ambiguous change sets that are not safe for automatic conservative sync.
- Detached pinned modules remain unchanged; none showed a new pin movement on the branch that currently contains their detached HEAD.

## Modules Checked

- `hiddify-app`
- `hiddify-core`
- `hiddify-core/hiddify-sing-box`
- `hiddify-core/ray2sing`
- `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
- `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
- `hiddify-core/hiddify-sing-box/replace/tailscale`
- `hiddify-core/hiddify-sing-box/replace/wireguard-go`

## Module Status

- `hiddify-app`
  - branch: `codex/windows-tun-stability-baseline`
  - tracking branch: `origin/codex/windows-tun-stability-baseline` (`0 ahead / 0 behind`)
  - fork default branch: `origin/main` (`22 ahead / 0 behind`)
  - true upstream compare: `hiddify/hiddify-app main` at `210548d7` (`22 ahead / 41 behind`)
  - cleanliness: clean
  - result: blocked for automatic sync; upstream-only range is a large Flutter/UI/router feature stack, not a clearly applicable low-risk update set

- `hiddify-core`
  - branch: `codex/windows-tun-dns`
  - tracking branch: `origin/codex/windows-tun-dns` (`0 ahead / 0 behind`)
  - fork default branch: `origin/main` (`21 ahead / 0 behind`)
  - true upstream compare: `hiddify/hiddify-core main` at `f2034de` (`21 ahead / 8 behind`)
  - cleanliness: clean
  - result: blocked for automatic sync; missing commits include `add ezytel cmd`, `add health check, speedtest and vlessenc`, and Clash-format parsing changes, which need deliberate integration review rather than blind cherry-pick

- `hiddify-core/hiddify-sing-box`
  - branch: `extended`
  - tracking branch: `origin/extended` (`0 ahead / 0 behind`)
  - true upstream compare: `hiddify/hiddify-sing-box extended` at `d7555775` (`10 ahead / 16 behind`)
  - cleanliness: clean
  - result: blocked for automatic sync; upstream-only range includes `smart_dns_pool` and `GooseRelay` feature work plus follow-up fixes, so applicability is not low-risk or obvious against local Windows networking protections

- `hiddify-core/ray2sing`
  - branch: `codex/catch-up-amnezia-warp`
  - tracking branch: `fork/codex/catch-up-amnezia-warp` (`0 ahead / 0 behind`)
  - upstream compare: `hiddify/ray2sing main` at `caf5e9a` (`1 ahead / 0 behind`)
  - cleanliness: clean
  - result: no new upstream movement to integrate; local branch still carries one compatibility commit above upstream

- `replace/psiphon-quic-go`
  - detached at `47042a7c`
  - containing remote branch: `origin/master` (`0 ahead / 0 behind`)
  - cleanliness: clean
  - result: unchanged detached pin; no update

- `replace/psiphon-tls`
  - detached at `4af85c2`
  - containing remote branch: `origin/master` (`0 ahead / 0 behind`)
  - cleanliness: clean
  - result: unchanged detached pin; no update

- `replace/tailscale`
  - detached at `288bae820`
  - containing remote branch: `origin/v1.92.4-sing-box-1.13-mod.6-e` (`0 ahead / 0 behind`)
  - default branch `origin/dev` delta: `19 ahead / 0 behind`
  - cleanliness: clean
  - result: unchanged detached pin; no new pin movement, so no action

- `replace/wireguard-go`
  - detached at `b120224`
  - containing remote branch: `origin/new` (`0 ahead / 0 behind`)
  - default branch `origin/main` delta: `53 ahead / 23 behind`
  - cleanliness: clean
  - result: unchanged detached pin with divergent default branch lineage; keep blocked from automatic sync

## Validation

- `git diff --check` passed in:
  - `hiddify-app`
  - `hiddify-core`
  - `hiddify-core/hiddify-sing-box`
  - `hiddify-core/ray2sing`

## Outcome

- Commits created: none
- Pushes performed: none
- Modules updated: none
- Modules blocked/skipped:
  - `hiddify-app`
  - `hiddify-core`
  - `hiddify-core/hiddify-sing-box`
  - `replace/wireguard-go`
  - Detached pins left unchanged by policy: `replace/psiphon-quic-go`, `replace/psiphon-tls`, `replace/tailscale`
