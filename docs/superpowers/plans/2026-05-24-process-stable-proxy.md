# Process Stable Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable per-process proxy rule that routes selected processes through a stable proxy group which excludes Naive and QUIC-like outbounds by default, with Codex processes selected by default.

**Architecture:** Extend the existing process direct rule pattern instead of changing the global `lowest` selector. The core config builder creates a filtered balancer/selector outbound and inserts process route rules to that outbound before general proxy routing. Flutter preferences expose enable/list/excluded-keyword settings and reuse the existing running-process selection UI shape.

**Tech Stack:** Go hiddify-core config builder, sing-box route/outbound options, Flutter/Riverpod preferences, Freezed JSON models.

---

### Task 1: Core Config Behavior

**Files:**
- Modify: `hiddify-core/v2/config/hiddify_option.go`
- Modify: `hiddify-core/v2/config/builder.go`
- Create: `hiddify-core/v2/config/process_stable_proxy_rules.go`
- Test: `hiddify-core/v2/config/process_stable_proxy_rules_test.go`

- [ ] Write failing Go tests for filtered stable proxy group and process route.
- [ ] Implement new route option fields and filtered outbound helpers.
- [ ] Run focused Go config tests.

### Task 2: Flutter Config Persistence

**Files:**
- Modify: `lib/features/settings/data/config_option_repository.dart`
- Modify: `lib/singbox/model/singbox_config_option.dart`
- Modify generated Freezed/JSON files via build runner.
- Test: `test/features/settings/data/config_option_repository_test.dart`
- Test: `test/singbox/model/singbox_config_option_test.dart`

- [ ] Write failing Dart tests for Codex defaults and JSON fields.
- [ ] Add preferences and model fields.
- [ ] Regenerate Dart model code and run focused Flutter tests.

### Task 3: Settings UI

**Files:**
- Modify: `lib/features/settings/overview/sections/route_options_page.dart`
- Create or generalize page code for stable proxy process selection.

- [ ] Reuse the existing process list selection pattern for stable proxy process names.
- [ ] Add a route settings toggle and process summary tile.
- [ ] Keep advanced excluded-keyword configuration out of the first UI pass; use defaults in config.

### Verification

- [ ] `go test ./v2/config`
- [ ] focused Flutter tests for config repository and singbox model
- [ ] Inspect generated config to confirm `process-stable-proxy` excludes Naive/QUIC names and Codex process names route to it.
