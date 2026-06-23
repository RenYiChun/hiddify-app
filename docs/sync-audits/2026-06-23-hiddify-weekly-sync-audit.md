# Hiddify Weekly Sync Audit - 2026-06-23

Run time: `2026-06-23 12:44:29 +08:00`

Mode: catch-up, with hard stops for dirty worktrees, detached pins, ambiguous lineage, conflicts that risk protected behavior, test failures, and push failures.

Protected local behavior for this run:

- Windows TUN behavior
- Dynamic direct bypass behavior
- Direct DNS fallback behavior

## Summary

Fetched/pruned/tags for root `hiddify-app` and every recursive submodule discovered by `git submodule status --recursive`.

Updated modules:

- `hiddify-core`
  - Cherry-picked upstream `hiddify/hiddify-core` commit `2b5f099 feat: add GetLANIP RPC method and LANIPResponse message`.
  - Local commit: `e65b98f feat: add GetLANIP RPC method and LANIPResponse message`.
  - Resolved one conflict in `v2/hcore/commands.go` by preserving local URL-test routing behavior and adding only the upstream LAN IP RPC implementation.
  - Pushed to `origin/codex/windows-tun-dns`.

- `hiddify-app`
  - Updated the `hiddify-core` submodule pointer from `d1228d06` to `e65b98f8`.
  - Cherry-picked seven clean root bug/security fixes from `hiddify/hiddify-app`:
    - `894c2f9 fix: add confirmation for deep link profile addition to prevent SSRF`
    - `0b577ef fix: resolve ChainTimelineHeader background visibility in light theme`
    - `641c43f fix: correct arrow icon direction in chain quick settings`
    - `7332bca fix(router): pass triggeredByDeepLink flag when auto-importing profiles`
    - `0ccf876 Fix AppImage launch crashes with launcher %u args and enable deep-linking`
    - `0dfb984 Guard notifications against a missing toast overlay`
    - `276d65a fix(profile): treat subscription-userinfo total=0 as unlimited (#1974)`

Unchanged branch-based modules:

- `hiddify-core/hiddify-sing-box`
  - Branch `extended`, upstream `origin/extended`, `0 ahead / 0 behind`.
  - Official `hiddify/hiddify-sing-box extended` had no missing upstream commits for this checkout.

- `hiddify-core/ray2sing`
  - Branch `codex/catch-up-amnezia-warp`, upstream `fork/codex/catch-up-amnezia-warp`, `0 ahead / 0 behind`.
  - Official `hiddify/ray2sing main` had no missing upstream commits for this checkout.

Detached pin modules left unchanged:

- `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
  - Detached at `47042a7c2475`, contained by `origin/master`, no default-branch delta.

- `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
  - Detached at `4af85c2fb9f2`, contained by `origin/master`, no default-branch delta.

- `hiddify-core/hiddify-sing-box/replace/tailscale`
  - Detached at `288bae820069`, contained by `origin/v1.92.4-sing-box-1.13-mod.6-e`.
  - Default `origin/dev` compared as `19 ahead / 0 behind`; still a pin-policy module, so it was not moved.

- `hiddify-core/hiddify-sing-box/replace/wireguard-go`
  - Detached at `b12022450359`, contained by `origin/new`.
  - Default `origin/main` compared as `53 ahead / 23 behind`; lineage remains ambiguous, so it was not moved.

## Remaining Blockers

Root `hiddify-app` still has a broad official upstream delta after the safe cherry-picks. The remaining non-merge upstream commits are blocked for this automated run because the conflict matrix shows overlap with local translations, generated bindings, settings, routing, bootstrap, dependency, and protobuf surfaces.

Representative blocked commits:

- `8cbe5746 refactor: use slang translations for add profile dialog`
- `fc4631ad feat: add Psiphon override support and unified chain license flow`
- `54842a2d chore: regenerate protobuf bindings`
- `3f60de68 build: update dependencies and remove unused packages`
- `0242b0cd refactor: resolve LAN IP via core RPC in settings`
- `961f6115 feat(settings): add new port configuration options and integrate with inbound options page`
- `6b116d2f Make hiddify-core init non-fatal during bootstrap`
- `f5d01fd6 feat(settings): implement LAN sharing functionality with password support and UI integration`
- `ad2af9fe`, `ca7c2bd5`, and `3fc523ce` route-rule deep-link changes

These should be handled as an explicit root catch-up planning task rather than forced through the weekly automation.

`hiddify-core` still compares as behind the official merge commit by raw commit graph because the upstream commit was cherry-picked with local conflict resolution and does not share the original patch id exactly. The LAN IP RPC behavior itself is present in local commit `e65b98f`.

## Validation

Passed:

- `go test ./v2/hcore ./v2/ezytel ./v2/config` in `hiddify-core`
- `flutter test test/features/profile/data/profile_parser_test.dart test/hiddifycore/hiddify_core_service_status_test.dart` in root
- `git diff --check` and `git diff --cached --check` in every discovered repository/module

Skipped:

- Broader Flutter tests, because the applied root changes were narrow and the conflicting upstream feature/dependency/protobuf sequence was not integrated.
- Pin advancement tests for detached replace modules, because no explicit pin movement decision was available.

## Final Module Inventory

- `hiddify-app`: branch `codex/windows-tun-stability-baseline`, clean, ahead of `origin/codex/windows-tun-stability-baseline` pending root publish.
- `hiddify-core`: branch `codex/windows-tun-dns`, clean, pushed to `origin/codex/windows-tun-dns`.
- `hiddify-core/hiddify-sing-box`: branch `extended`, clean, unchanged.
- `hiddify-core/ray2sing`: branch `codex/catch-up-amnezia-warp`, clean, unchanged.
- `psiphon-quic-go`: detached clean pin, unchanged.
- `psiphon-tls`: detached clean pin, unchanged.
- `tailscale`: detached clean pin, unchanged.
- `wireguard-go`: detached clean pin, unchanged and still ambiguous against `origin/main`.

`last-catch-up-baseline.md` was not updated because this run did not complete a full root upstream catch-up.
