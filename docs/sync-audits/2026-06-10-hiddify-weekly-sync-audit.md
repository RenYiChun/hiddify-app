# Hiddify Weekly Sync Audit - 2026-06-10

Workspace: `D:\github.com\hiddify-app`

Mode: catch-up policy with detached-pin hard stops (`docs/sync-audits/sync-policy.md`)

## Summary

- Re-read the repo-backed sync policy, prior catch-up baseline, and the last weekly audit before scanning the full recursive tree again.
- Fetched `--all --prune --tags` for the root repository and every discovered recursive submodule.
- Compared branch-based modules against both their configured tracking branch and the official `hiddify/*` upstream branch without changing local remote configuration.
- No repository had new upstream commits to integrate on a safe, branch-based path. The only visible remote delta remains on detached `replace/wireguard-go`, which stays blocked by policy.

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
  - remote(s): `origin=git@github.com:RenYiChun/hiddify-app.git`
  - tracking branch: `origin/codex/windows-tun-stability-baseline` (`0 ahead / 0 behind`)
  - fork default branch: `origin/main` (`66 ahead / 0 behind`)
  - official upstream compare: `hiddify/hiddify-app main` at `210548d70015` (`25 ahead / 0 behind`)
  - cleanliness: clean
  - result: no new upstream movement; no action

- `hiddify-core`
  - branch: `codex/windows-tun-dns`
  - remote(s): `origin=git@github.com:RenYiChun/hiddify-core.git`
  - tracking branch: `origin/codex/windows-tun-dns` (`0 ahead / 0 behind`)
  - fork default branch: `origin/main` (`31 ahead / 0 behind`)
  - official upstream compare: `hiddify/hiddify-core main` at `f2034de743b1` (`23 ahead / 0 behind`)
  - cleanliness: clean
  - result: no new upstream movement; no action

- `hiddify-core/hiddify-sing-box`
  - branch: `extended`
  - remote(s): `origin=https://github.com/RenYiChun/hiddify-sing-box.git`
  - tracking branch: `origin/extended` (`0 ahead / 0 behind`)
  - official upstream compare: `hiddify/hiddify-sing-box extended` at `d75557751415` (`11 ahead / 0 behind`)
  - cleanliness: clean
  - result: no new upstream movement; no action

- `hiddify-core/ray2sing`
  - branch: `codex/catch-up-amnezia-warp`
  - remote(s): `fork=https://github.com/RenYiChun/ray2sing.git`, `origin=git@github.com:hiddify/ray2sing.git`
  - tracking branch: `fork/codex/catch-up-amnezia-warp` (`0 ahead / 0 behind`)
  - official upstream compare: `hiddify/ray2sing main` at `caf5e9ac03ea` (`1 ahead / 0 behind`)
  - cleanliness: clean
  - result: no new upstream movement; local compatibility commit still sits one commit above upstream

- `replace/psiphon-quic-go`
  - detached at `47042a7c2475`
  - remote(s): `origin=git@github.com:hiddify/psiphon-quic-go`
  - containing remote branch: `origin/master` (`0 ahead / 0 behind`)
  - cleanliness: clean
  - result: detached pin; blocked from automatic sync, but no new pin movement detected

- `replace/psiphon-tls`
  - detached at `4af85c2fb9f2`
  - remote(s): `origin=git@github.com:hiddify/psiphon-tls`
  - containing remote branch: `origin/master` (`0 ahead / 0 behind`)
  - cleanliness: clean
  - result: detached pin; blocked from automatic sync, but no new pin movement detected

- `replace/tailscale`
  - detached at `288bae820069`
  - remote(s): `origin=git@github.com:hiddify/tailscale`
  - containing remote branch: `origin/v1.92.4-sing-box-1.13-mod.6-e` (`0 ahead / 0 behind`)
  - default branch delta: `origin/dev` (`19 ahead / 0 behind`)
  - cleanliness: clean
  - result: detached pin; blocked from automatic sync, and the pinned branch itself did not move

- `replace/wireguard-go`
  - detached at `b12022450359`
  - remote(s): `origin=git@github.com:hiddify/wireguard-go`
  - containing remote branch: `origin/new` (`0 ahead / 0 behind`)
  - default branch delta: `origin/main` (`53 ahead / 23 behind`)
  - cleanliness: clean
  - result: blocked; detached pin plus ambiguous lineage between `origin/new` and `origin/main`, with new commits only visible on the default branch side

## Validation

- `git diff --check` passed in:
  - `hiddify-app`
  - `hiddify-core`
  - `hiddify-core/hiddify-sing-box`
  - `hiddify-core/ray2sing`

## Outcome

- Commits created: none
- Pushes performed: none
- Tests run: none, because no module advanced to a code-change state
- Modules updated: none
- Modules blocked/skipped:
  - Detached by policy: `replace/psiphon-quic-go`, `replace/psiphon-tls`, `replace/tailscale`
  - Ambiguous detached lineage: `replace/wireguard-go`
