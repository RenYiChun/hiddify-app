# Hiddify Weekly Sync Audit - 2026-06-30

Run time: `2026-06-30 13:39:09 +08:00`

Mode: catch-up, with hard stops for detached pins, ambiguous lineage, conflicts that risk protected behavior, test failures, and push failures.

Protected local behavior for this run:

- Windows TUN behavior
- Dynamic direct bypass behavior
- Direct DNS fallback behavior

## Summary

The root worktree initially contained local logger/logging edits from a prior run. Per explicit user instruction, those uncommitted root changes were discarded before sync:

- `lib/core/logger/custom_logger.dart`
- `lib/core/logger/logger.dart`
- `lib/core/logger/logger_controller.dart`
- `lib/features/log/data/log_parser.dart`
- `lib/features/log/data/log_repository.dart`
- `lib/main.dart`
- `lib/main_prod.dart`
- `test/core/logger/custom_logger_test.dart`
- `test/core/logger/logger_controller_test.dart`
- `test/features/log/data/log_parser_test.dart`

Fetched/pruned/tags for root `hiddify-app` and every recursive submodule discovered by `git submodule status --recursive`.

Updated modules:

- `hiddify-app`
  - Cherry-picked upstream `hiddify/hiddify-app` commit `6b116d2 Make hiddify-core init non-fatal during bootstrap`.
    - Local commit: `eb3006a Make hiddify-core init non-fatal during bootstrap`.
  - Cherry-picked upstream `hiddify/hiddify-app` commit `14654bd chore(makefile): optimize Linux docker builds and fix core download URL`.
    - Local commit: `d43ec90 chore(makefile): optimize Linux docker builds and fix core download URL`.
  - Cherry-picked upstream `hiddify/hiddify-app` commit `787dcf9 feat(linux): enhance desktop entry with localization and AppImage update keys`.
    - Local commit: `071cffa feat(linux): enhance desktop entry with localization and AppImage update keys`.

Unchanged branch-based modules:

- `hiddify-core`
  - Branch `codex/windows-tun-dns`, upstream `origin/codex/windows-tun-dns`, `0 ahead / 0 behind`.
  - Official `hiddify/hiddify-core main` still conflicts in `v2/hcore/commands.go` during full merge assessment.

- `hiddify-core/hiddify-sing-box`
  - Branch `extended`, upstream `origin/extended`, `0 ahead / 0 behind`.
  - Official `hiddify/hiddify-sing-box extended` had no upstream-only commits by patch-equivalence.

- `hiddify-core/ray2sing`
  - Branch `codex/catch-up-amnezia-warp`, upstream `fork/codex/catch-up-amnezia-warp`, `0 ahead / 0 behind`.
  - Official `hiddify/ray2sing main` had no upstream-only commits by patch-equivalence.

Detached pin modules left unchanged:

- `hiddify-core/hiddify-sing-box/replace/psiphon-quic-go`
  - Detached at `47042a7c2475`, matching `origin/master`.

- `hiddify-core/hiddify-sing-box/replace/psiphon-tls`
  - Detached at `4af85c2fb9f2`, matching `origin/master`.

- `hiddify-core/hiddify-sing-box/replace/tailscale`
  - Detached at `288bae820069`, contained by `origin/v1.92.4-sing-box-1.13-mod.6-e`.
  - Not moved because catch-up mode does not automatically advance detached pins.

- `hiddify-core/hiddify-sing-box/replace/wireguard-go`
  - Detached at `b12022450359`, matching `origin/new`.
  - Still diverged from default `origin/main`, so it remains a pin-policy blocker.

## Remaining Blockers

Full root catch-up to official `hiddify/hiddify-app main` remains blocked. `git merge-tree --write-tree HEAD codex-upstream/main` reported conflicts across routing/settings/protobuf/generated/core-service surfaces, including:

- `lib/core/router/bottom_sheets/bottom_sheets_notifier.dart`
- `lib/features/connection/data/connection_repository.dart`
- `lib/features/route_rules/notifier/rules_notifier.dart`
- `lib/features/settings/data/config_option_repository.dart`
- many `lib/hiddifycore/generated/**` files
- `lib/hiddifycore/hiddify_core_service.dart`
- `lib/singbox/model/singbox_config_option.dart`
- `pubspec.lock`

One attempted translation-only cherry-pick was aborted:

- `46101cb fix: add missing required text to fa WARP missingLicense translation`
  - Blocked by a content conflict in `assets/translations/fa.i18n.json`.

The remaining upstream feature/dependency/protobuf/routing chain should be handled as an explicit root catch-up planning task, not forced through this weekly automation.

## Validation

Passed:

- `flutter test test/hiddifycore/hiddify_core_service_status_test.dart`
- `flutter analyze lib/bootstrap.dart`
- `git diff --check` and `git diff --cached --check` in every discovered repository/module

Skipped:

- Go tests, because no Go module changed.
- Detached pin advancement tests, because no pin was moved.

## Final Module Inventory

- `hiddify-app`: branch `codex/windows-tun-stability-baseline`, ahead of `origin/codex/windows-tun-stability-baseline` pending validation and publish.
- `hiddify-core`: branch `codex/windows-tun-dns`, clean, unchanged.
- `hiddify-core/hiddify-sing-box`: branch `extended`, clean, unchanged.
- `hiddify-core/ray2sing`: branch `codex/catch-up-amnezia-warp`, clean, unchanged.
- `psiphon-quic-go`: detached clean pin, unchanged.
- `psiphon-tls`: detached clean pin, unchanged.
- `tailscale`: detached clean pin, unchanged.
- `wireguard-go`: detached clean pin, unchanged and still ambiguous against `origin/main`.

`last-catch-up-baseline.md` was not updated because this run did not complete a full root upstream catch-up.
