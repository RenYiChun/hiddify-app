# Hiddify Catch-Up Sync Audit - 2026-06-03

Workspace: `D:\github.com\hiddify-app`

Mode: catch-up sync (`docs/sync-audits/sync-policy.md`)

## Summary

- Continued the full recursive module catch-up after the policy change from conservative-only sync.
- Advanced and integrated upstream movement in `ray2sing`, `replace/tailscale`, `hiddify-sing-box`, and `hiddify-core`.
- Preserved local Windows TUN, dynamic direct bypass, direct DNS fallback, embedded rule-set refresh, and startup timing behavior while merging `hiddify-core` upstream `origin/main`.
- Created a `RenYiChun/ray2sing` fork because the current account has only READ permission on `hiddify/ray2sing`; updated the `hiddify-core` submodule URL so the recorded ray2sing commit is fetchable.

## Modules Checked

- `hiddify-app`
- `hiddify-core`
- `hiddify-core/hiddify-sing-box`
- `hiddify-core/ray2sing`
- `hiddify-core/hiddify-sing-box/replace/tailscale`
- `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
- `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
- `hiddify-core/hiddify-sing-box/replace/wireguard-go`

## Updates Integrated

- `replace/tailscale`: advanced from `788aa623e` to `288bae820`.
- `ray2sing`: advanced from `c0c298d` through upstream `caf5e9a`, then local catch-up fix `232398c`.
- `hiddify-sing-box`: added AWG/WARP option compatibility for ray2sing Amnezia/WARP output and recorded the tailscale pointer.
- `hiddify-core`: recorded updated `hiddify-sing-box` and `ray2sing` pointers, switched ray2sing submodule URL to `https://github.com/RenYiChun/ray2sing.git`, and merged `origin/main`.
- `hiddify-app`: recorded the updated `hiddify-core` pointer.

## Commits Created And Pushed

- `ray2sing`: `232398c fix: align ray2sing catch-up dependencies`
  - Pushed to `RenYiChun/ray2sing`, branch `codex/catch-up-amnezia-warp`.
- `hiddify-sing-box`: `0ba9761d fix: support WARP AWG catch-up options`
  - Pushed to `RenYiChun/hiddify-sing-box`, branch `extended`.
- `hiddify-core`: `3297df8 chore: update synced submodules`
  - Pushed to `RenYiChun/hiddify-core`, branch `codex/windows-tun-dns`.
- `hiddify-core`: `08b544b Merge remote-tracking branch 'origin/main' into codex/windows-tun-dns`
  - Pushed to `RenYiChun/hiddify-core`, branch `codex/windows-tun-dns`.
- `hiddify-app`: root pointer/audit commit is the commit containing this audit file.

## Validation

- `replace/tailscale`: `go test ./tsnet ./wgengine/netstack ./wgengine/magicsock ./net/netcheck ./net/netns ./ipn/ipnlocal ./wgengine/router/osrouter ./wgengine`
- `hiddify-sing-box`: `go test ./option ./protocol/awg ./protocol/hiddify/dnstt ./protocol/wireguard`
- `ray2sing`: `go test ./...`
- `hiddify-core`: `go test ./v2/hcore ./v2/config ./v2/ezytel`
- `git diff --check` passed in changed repositories before commit.

## Notes

- `ray2sing` `TestBeePass` now skips the remote S3 fixture because anonymous access currently returns `AccessDenied`; the rest of `go test ./...` passes.
- `hiddify-core` `origin/main` merge produced conflicts in `v2/hcore/grpc_server.go` and `v2/hcore/start.go`; both resolved by preserving existing local startup behavior and keeping ezytel registration.
- `psiphon-quic-go`, `psiphon-tls`, and `wireguard-go` had no pointer changes in this catch-up.
