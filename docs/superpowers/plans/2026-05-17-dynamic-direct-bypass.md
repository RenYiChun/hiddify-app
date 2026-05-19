# Dynamic Direct Bypass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Windows VPN/TUN instability caused by high-volume direct traffic filling sing-box direct connection admission by automatically bypassing hot direct destinations at the OS route layer.

**Architecture:** The core service owns a Windows-only dynamic bypass manager. It samples in-process Clash traffic metadata, detects direct-routed domains with many active flows, extracts observed destination IPs and optional DNS results, adds temporary /32 host routes through the physical default gateway, caches entries with TTL, and removes routes on stop. sing-box route admission remains a fallback rather than the primary pressure valve.

**Tech Stack:** Go in `hiddify-core`, sing-box `trafficontrol.Manager`, Windows `route.exe`/PowerShell route discovery behind an interface, existing HiddifyOptions JSON/custom option plumbing, Dart settings model for persisted configuration.

---

### Defaults

- Enabled only when `enable-tun=true` and the platform is Windows.
- Default config values:
  - `enable-dynamic-direct-bypass=true`
  - `dynamic-direct-bypass-threshold=128`
  - `dynamic-direct-bypass-ttl=1800` seconds
  - `dynamic-direct-bypass-max-routes=512`
  - `dynamic-direct-bypass-max-routes-per-host=32`
- A host becomes eligible only when direct active connection count reaches the threshold in one sampling window.
- The first implementation only adds public IPv4 /32 routes. IPv6 remains untouched because current Windows VPN mode is configured as IPv4-only.
- Routes are non-persistent and must be removed on `StopService`. Cache exists to reapply still-fresh entries on the next start, not to permanently alter the machine.

### Detection

- Source: `HiddifyInstance.TrafficManager().Connections()`.
- Eligible connection:
  - terminal outbound type is `direct`, or the outbound chain contains `direct §hide§`;
  - destination host is present;
  - destination IP is a public IPv4 address;
  - destination IP is not a proxy server, DNS server, loopback, private, multicast, or unspecified address.
- Group by host, then add observed IPs for hosts above threshold.
- DNS expansion is allowed but bounded by max routes per host; observed IPs are preferred.

### Route Operations

- Route operations are abstracted behind an interface so tests never modify the host route table.
- Windows implementation:
  - discover physical default route excluding `sing-tun` and Hyper-V/loopback-like interfaces;
  - add `route ADD <ip> MASK 255.255.255.255 <gateway> METRIC 1 IF <ifIndex>`;
  - delete `route DELETE <ip>`.
- Failures are logged as warnings and do not fail VPN startup.

### Lifecycle

- Start manager after `NewService` succeeds and `static.StartedService` is assigned.
- Stop manager before closing sing-box service, then remove dynamic routes.
- If startup fails, no dynamic routes are added.

### Tests

- Unit tests for candidate detection: hot direct host is selected, proxy traffic and low-count direct traffic are ignored.
- Unit tests for IP filtering: private, loopback, DNS/proxy server IPs are ignored.
- Unit tests for route apply/cache/TTL: routes are added once, expired routes are deleted, stop removes active routes.
- Unit tests for config plumbing: HiddifyOptions writes dynamic bypass custom values and hcore reads defaults safely.
