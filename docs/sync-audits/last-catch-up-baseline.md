# Last Catch-Up Baseline

Last full catch-up established: `2026-06-03 17:15:00 +08:00`

Source snapshot: [`2026-06-03-hiddify-catch-up-sync.md`](./2026-06-03-hiddify-catch-up-sync.md)

This file records the last known module positions after a successful deepest-first catch-up publish. Future weekly sync runs should read this file first so they can compare from a stable, known-good baseline instead of rediscovering the last catch-up state from memory.

## Baseline Repositories And Positions

- `hiddify-app`
  - branch: `codex/windows-tun-stability-baseline`
  - remote: `RenYiChun/hiddify-app`
  - pushed state after catch-up: `0 ahead / 0 behind`
  - root commit recorded after catch-up flow: `28392f70 chore: record hiddify catch-up sync`

- `hiddify-core`
  - branch: `codex/windows-tun-dns`
  - remote: `RenYiChun/hiddify-core`
  - pushed state after catch-up: `0 ahead / 0 behind`
  - commits recorded in that catch-up:
    - `3297df8 chore: update synced submodules`
    - `08b544b Merge remote-tracking branch 'origin/main' into codex/windows-tun-dns`

- `hiddify-core/hiddify-sing-box`
  - branch: `extended`
  - remote: `RenYiChun/hiddify-sing-box`
  - pushed state after catch-up: `0 ahead / 0 behind`
  - catch-up commit: `0ba9761d fix: support WARP AWG catch-up options`

- `hiddify-core/ray2sing`
  - branch: `codex/catch-up-amnezia-warp`
  - remote: `RenYiChun/ray2sing`
  - pushed state after catch-up: `0 ahead / 0 behind`
  - catch-up commit: `232398c fix: align ray2sing catch-up dependencies`

## Baseline Detached Pins

- `hiddify-core/hiddify-sing-box/replace/tailscale`
  - pinned commit: `288bae820`
  - note: advanced during the 2026-06-03 catch-up run and validated there

- `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
  - pinned commit: `47042a7c`

- `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
  - pinned commit: `4af85c2`

- `hiddify-core/hiddify-sing-box/replace/wireguard-go`
  - pinned commit: `b120224`

## Protected Local Behavior Preserved At This Baseline

- Windows TUN behavior
- Dynamic direct bypass behavior
- Direct DNS fallback behavior

## Update Rule

Only update this file when a run actually completes a new full catch-up baseline across the affected dependency layers and the resulting commits/pins have been validated and pushed in deepest-first order.
