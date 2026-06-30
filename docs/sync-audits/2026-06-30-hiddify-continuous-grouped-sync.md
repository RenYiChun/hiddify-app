# Hiddify Continuous Grouped Sync Audit - 2026-06-30

## Scope

This run continued from the WARP i18n sync baseline:

- root `hiddify-app`: `8b0c56ca9dc5b1a77702a7a17dae37f3059bab32`
- branch: `codex/windows-tun-stability-baseline`
- mode: process every remaining upstream group continuously, one coherent group at a time
- protected behavior: Windows TUN, dynamic direct bypass, direct DNS fallback

Recursive modules were inventoried with `git submodule status --recursive`. No submodule pointer was changed in this run.

## Updated Root Groups

### Add Profile Slang And Deep-Link Warning I18n

Applied upstream commits:

- `1dd5af25` from `8cbe574`: use slang translations for add profile dialog
- `149b2286` from `01f46b4`: upstream search/replace translation update
- `d4eef0d1` from `d05adc6`: rename addProfileFromLink key and add translations
- `a2c6cfd9` from `6127ce1`: add addProfileByDeepLinkWarning translations

Validation:

- `dart run slang`
- `flutter analyze lib/core/router/bottom_sheets/bottom_sheets_notifier.dart lib/gen/translations.g.dart`

### Psiphon License Chain

Applied upstream commits:

- `f5323fd6` from `fc4631a`: Psiphon override support and unified chain license flow
- `29c224be` from `15aa004`: Psiphon translations and WARP punctuation updates
- `94f571f0` from `fb1dc8f`: Psiphon license translations and WARP message updates

Conflict handling:

- Preserved local `normalizeCoreRuntimeOptions` use before license checks.
- Preserved Windows port reservation behavior before applying runtime options.
- Preserved local WARP title wording in `fa` and `tr` while adding Psiphon license translations.

Validation:

- `dart run build_runner build --delete-conflicting-outputs`
- `dart run slang`
- `flutter test test/features/profile/data/profile_parser_test.dart test/features/connection/data/connection_repository_status_test.dart test/features/connection/model/connection_status_test.dart`
- `flutter analyze lib/features/connection/data/connection_repository.dart lib/core/router/dialog/dialog_notifier.dart lib/core/router/dialog/widgets/chain_license_dialog.dart lib/features/profile/data/profile_parser.dart lib/features/profile/model/profile_entity.dart`

Analyze limitation:

- The targeted analyze still reports the existing local `visibleForTesting` access to `normalizeCoreRuntimeOptions` and import ordering in `connection_repository.dart`. This was not changed because the helper is part of the protected runtime-normalization behavior.

### Profile File Import

Applied upstream commits:

- `3236d9bc` from `c2f9ac7`: add file import option for profiles
- `19303072` from `0f3c370`: add common.file translations

Validation:

- `dart run slang`
- `flutter analyze lib/features/profile/add/add_profile_modal.dart lib/features/profile/add/widgets/fix_btns.dart lib/core/model/constants.dart`
- `flutter test test/features/profile/data/profile_parser_test.dart`

### LAN Sharing Settings

Applied upstream commits:

- `32829277` from `13c24d5`: trailing widget support for preferences
- `5cb56bd1` from `961f611`: port configuration options
- `385ec310` from `f5d01fd`: LAN sharing UI
- `9b1e4e2c` from `fbf6abc`: Spanish LAN sharing translations
- `0bbd349b` from `811f3dc`: non-English LAN sharing translations
- `70ebfa89` from `d03318f`: Turkish LAN sharing translations
- `548076a8` from `9de86aa`: move LAN sharing password to config options
- `332052a7`: local compatibility fix for the current core bridge

Conflict handling:

- Kept local dynamic direct bypass, process direct, process stable proxy, and route connection limit fields.
- Integrated `lanSharingPassword` into `ConfigOptions` and `SingboxConfigOption`.
- Kept LAN sharing IP resolution on the current `network_info_plus` path because the core RPC/Dart generated bridge is not safely synced yet.

Validation:

- `dart run build_runner build --delete-conflicting-outputs`
- `dart run slang`
- `flutter analyze lib/features/settings/data/config_option_repository.dart lib/features/settings/overview/sections/inbound_options_page.dart lib/features/settings/widget/lan_sharing_tile.dart lib/core/preferences/general_preferences.dart lib/core/router/bottom_sheets/widgets/quick_settings_modal.dart lib/singbox/model/singbox_config_option.dart lib/gen/translations.g.dart test/singbox/model/singbox_config_option_test.dart test/features/settings/data/config_option_repository_test.dart`
- `flutter test test/features/settings/data/config_option_repository_test.dart test/singbox/model/singbox_config_option_test.dart test/core/preferences/preferences_migration_test.dart`

### Route Rule Deep-Link Import/Export

Applied upstream commits:

- `54aae5c3` from `f9686c9`: importRouteRuleByDeepLinkWarning base translation
- `757f5279` from `ad2af9f`: routeRule parameter on RoutingOptionsPage
- `5567baf0` from `ca7c2bd`: clipboard import/export with deep link support
- `9f9ca20f` from `3fc523c`: deep link handling in go_router
- `a2d5673c` from `b7931f1`: additional importRouteRuleByDeepLinkWarning translations
- `b4a77925` from `8b07547`: remaining importRouteRuleByDeepLinkWarning translations

Conflict handling:

- Kept local route-rule reconnect behavior after route rule updates.
- Added the upstream confirmation dialog dependency for deep-link imports.

Validation:

- `dart run slang`
- `flutter analyze lib/features/route_rules/notifier/rules_notifier.dart lib/features/settings/overview/sections/routing_options_page.dart lib/core/router/go_router/routing_config_notifier.dart lib/gen/translations.g.dart`
- `flutter test test/features/route_rules/notifier/rules_notifier_test.dart`

### Translation Helper Tooling

Applied upstream commit:

- `28ea8d13` from `c50ce39`: Aider translation helper configuration and `SLANG.md`

Validation:

- `git diff --check HEAD^ HEAD`

## Already Covered By Current Branch

These upstream bugfixes were attempted and resulted in empty cherry-picks:

- `bf1006d9`: guard notifications against a missing toast overlay
- `3d9f7c93`: treat `subscription-userinfo total=0` as unlimited

They are recorded as already covered by the current branch rather than committed again as empty commits.

## Blocked Groups

### Protobuf / Generated / Core LAN IP RPC

Blocked commits:

- `54842a2d`: regenerate protobuf bindings
- `82ba5833`: sync proto files from hiddify-core
- `0242b0cd`: resolve LAN IP via core RPC in settings

Reason:

- The generated/protobuf group produced broad conflicts in `lib/hiddifycore/generated/**`.
- The root Dart generated bridge currently lacks `CoreClient.getLANIP` and `LANIPResponse`.
- Applying only the settings/core wrapper commit would fail analyze/tests without the generated bridge.

Current decision:

- Leave this group blocked until the protobuf/Dart generation baseline can be resolved as one generated-code sync.

### Dependency Cleanup And macOS Registrant

Blocked commits:

- `3f60de68`: update dependencies and remove unused packages
- `0299c1cc`: remove unused packages
- `865ea737`: update macOS plugin registrant after dependency removal

Reason:

- `pubspec.lock` conflicts with local package source/version state.
- The dependency group upgrades protobuf to 5.x and is coupled to the blocked generated/protobuf sync.
- It removes `network_info_plus`, which the accepted LAN sharing compatibility path still uses until the core LAN IP RPC bridge is safely synced.

Current decision:

- Leave this group blocked.

### Submodules

- `hiddify-core`: official main still conflicts in `v2/hcore/commands.go` for the full merge path.
- `hiddify-core/hiddify-sing-box`: no upstream-only patch delta by patch-equivalence in this run.
- `hiddify-core/ray2sing`: no upstream-only patch delta by patch-equivalence in this run.
- `psiphon-quic-go`: detached pin unchanged, matches `origin/master`.
- `psiphon-tls`: detached pin unchanged, matches `origin/master`.
- `tailscale`: detached pin unchanged at `288bae820069`.
- `wireguard-go`: detached pin unchanged at `b12022450359`.

## Final Gate

Final gate for this run should include:

- `git diff --check` and `git diff --cached --check` in root.
- `git diff --check` and `git diff --cached --check` in every recursive submodule.
- Clean root and submodule working trees before push.

This run did not update `last-catch-up-baseline.md` because the blocked protobuf/dependency groups and unchanged submodules mean this is not a new full catch-up baseline.
