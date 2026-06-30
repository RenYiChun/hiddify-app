# Hiddify Grouped Sync Audit - WARP License i18n

Run time: `2026-06-30 13:59:17 +08:00`

Mode: grouped sync. This run followed the one-group rule: classify remaining upstream changes first, then process one coherent bugfix group only.

Protected local behavior for this run:

- Windows TUN behavior
- Dynamic direct bypass behavior
- Direct DNS fallback behavior

## Group Selected

Selected group: WARP license translation bugfix.

Upstream source commits:

- `46101cb fix: add missing required text to fa WARP missingLicense translation`
- `9b0efc5 fix: correct Turkish translation for WARP license required`

Local result:

- `49b30ab fix: update WARP license translations`

Files changed:

- `assets/translations/fa.i18n.json`
- `assets/translations/tr.i18n.json`

The Persian upstream patch conflicted because the local `missingLicenseMsg` already had a different sentence ending. The resolved local commit applies only the intended `missingLicense` title correction and preserves the existing local message text.

## Module Inventory

Fetched/pruned/tags for root `hiddify-app` and every recursive submodule discovered by `git submodule status --recursive`.

Branch-based modules were clean and aligned with their configured tracking branches before this group was applied:

- `hiddify-app`: branch `codex/windows-tun-stability-baseline`, upstream `origin/codex/windows-tun-stability-baseline`, `0 ahead / 0 behind`.
- `hiddify-core`: branch `codex/windows-tun-dns`, upstream `origin/codex/windows-tun-dns`, `0 ahead / 0 behind`.
- `hiddify-core/hiddify-sing-box`: branch `extended`, upstream `origin/extended`, `0 ahead / 0 behind`.
- `hiddify-core/ray2sing`: branch `codex/catch-up-amnezia-warp`, upstream `fork/codex/catch-up-amnezia-warp`, `0 ahead / 0 behind`.

Detached pins left unchanged:

- `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
- `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
- `hiddify-core/hiddify-sing-box/replace/tailscale`
- `hiddify-core/hiddify-sing-box/replace/wireguard-go`

## Remaining Groups

Not processed in this run by policy:

- Add-profile dialog slang/refactor and translations.
- Psiphon override and unified chain license feature chain.
- File import profile feature.
- Protobuf/generated binding chain.
- Dependency cleanup chain.
- LAN sharing settings feature chain.
- Route-rule deep-link import/export feature chain.
- Full `hiddify-core` official merge, still requiring explicit conflict handling in `v2/hcore/commands.go`.
- Detached pin advancement for `tailscale` and `wireguard-go`.

## Validation

Passed:

- `ConvertFrom-Json -AsHashTable` parse validation for `assets/translations/fa.i18n.json` and `assets/translations/tr.i18n.json`.
- `git diff --check` for the translation files before commit.
- `git diff --check` and `git diff --cached --check` in every discovered repository/module.

Skipped:

- Flutter and Go tests, because this group changed only translation JSON text and no generated Dart files or Go modules.

## Baseline Note

`last-catch-up-baseline.md` was not updated because this run intentionally processed only one bugfix group and did not establish a full catch-up baseline.
