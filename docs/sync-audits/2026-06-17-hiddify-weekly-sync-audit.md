# Hiddify Weekly Sync Audit - 2026-06-17

Workspace: `D:\github.com\hiddify-app`

Run time: `2026-06-17 09:06:13 +08:00`

Mode: catch-up policy with detached-pin hard stops (`docs/sync-audits/sync-policy.md`)

## Summary

- Re-read the automation memory, repo-backed sync policy, latest audit pointer, and last catch-up baseline before scanning the recursive tree.
- Fetched `--all --prune --tags` for the root repository and every discovered recursive submodule.
- Compared branch-based modules against their configured tracking branches, fork/default refs, and official `hiddify/*` heads without changing remote configuration.
- No branch-based repository had upstream commits missing from the current checkout. No code or submodule pointer sync was applied.
- Detached replace modules stayed pinned. `replace/wireguard-go` remains blocked by ambiguous lineage: the checkout is exactly on `origin/new`, while `origin/main` has divergent history.

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
  - fork default branch: `origin/main` (`68 ahead / 0 behind`)
  - official upstream compare: `hiddify/hiddify-app main` at `210548d70015` (`27 ahead / 0 behind`)
  - cleanliness: clean
  - result: no missing upstream commits; no action

- `hiddify-core`
  - branch: `codex/windows-tun-dns`
  - remote(s): `origin=git@github.com:RenYiChun/hiddify-core.git`
  - tracking branch: `origin/codex/windows-tun-dns` (`0 ahead / 0 behind`)
  - fork default branch: `origin/main` (`31 ahead / 0 behind`)
  - official upstream compare: `hiddify/hiddify-core main` at `f2034de743b1` (`23 ahead / 0 behind`)
  - cleanliness: clean
  - result: no missing upstream commits; no action

- `hiddify-core/hiddify-sing-box`
  - branch: `extended`
  - remote(s): `origin=https://github.com/RenYiChun/hiddify-sing-box.git`
  - tracking branch: `origin/extended` (`0 ahead / 0 behind`)
  - fork default branch: `origin/extended` (`0 ahead / 0 behind`)
  - official upstream compare: `hiddify/hiddify-sing-box extended` at `d75557751415` (`11 ahead / 0 behind`)
  - cleanliness: clean
  - result: no missing upstream commits; no action

- `hiddify-core/ray2sing`
  - branch: `codex/catch-up-amnezia-warp`
  - remote(s): `fork=https://github.com/RenYiChun/ray2sing.git`, `origin=git@github.com:hiddify/ray2sing.git`
  - tracking branch: `fork/codex/catch-up-amnezia-warp` (`0 ahead / 0 behind`)
  - official upstream compare: `hiddify/ray2sing main` at `caf5e9ac03ea` (`1 ahead / 0 behind`)
  - cleanliness: clean
  - result: no missing upstream commits; local compatibility commit remains one commit above upstream

- `replace/psiphon-quic-go`
  - detached at `47042a7c2475`
  - remote(s): `origin=git@github.com:hiddify/psiphon-quic-go`
  - containing remote branch: `origin/master` (`0 ahead / 0 behind`)
  - cleanliness: clean
  - result: detached pin; blocked from automatic sync, with no new pin movement detected

- `replace/psiphon-tls`
  - detached at `4af85c2fb9f2`
  - remote(s): `origin=git@github.com:hiddify/psiphon-tls`
  - containing remote branch: `origin/master` (`0 ahead / 0 behind`)
  - cleanliness: clean
  - result: detached pin; blocked from automatic sync, with no new pin movement detected

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
  - default branch sample commits: `9a43935 Rename module`, `ec6c844 Add module_rename.py`, `a300191 Add pause support`
  - cleanliness: clean
  - result: blocked; detached pin plus ambiguous lineage between `origin/new` and `origin/main`

## Validation

- `git diff --check` passed in:
  - `hiddify-app`
  - `hiddify-core`
  - `hiddify-core/hiddify-sing-box`
  - `hiddify-core/ray2sing`
  - `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
  - `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
  - `hiddify-core/hiddify-sing-box/replace/tailscale`
  - `hiddify-core/hiddify-sing-box/replace/wireguard-go`

## Outcome

- Code or submodule-pointer commits created: none
- Code modules updated: none
- Go tests run: none, because no Go module advanced to a code-change state
- Flutter tests run: none, because no Flutter/Dart files changed
- Root audit docs changed: this file and `docs/sync-audits/latest.md`
- Modules blocked/skipped:
  - Detached by policy: `replace/psiphon-quic-go`, `replace/psiphon-tls`, `replace/tailscale`
  - Ambiguous detached lineage: `replace/wireguard-go`
