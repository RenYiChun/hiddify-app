# Hiddify Server Overrides

This document records the local server-side overrides that were applied while debugging
Windows TUN, Codex compact/update, Google Play, and Microsoft Store delivery failures.

These changes live outside the normal app repository when applied on a server, so they
can be lost during server rebuilds, migrations, or Hiddify manager upgrades. Keep this
document and `scripts/ops/apply-hiddify-server-overrides.sh` with the app branch and
reapply it after provisioning a new Hiddify server.

## Current Overrides

### Xray Route Guard

Installed server files:

- `/usr/local/sbin/hiddify-googleplay-route-guard`
- `/etc/systemd/system/hiddify-xray.service.d/10-googleplay-route-guard.conf`
- generated/runtime files patched by the guard:
  - `/opt/hiddify-manager/xray/configs/03_routing.json`
  - `/opt/hiddify-manager/xray/configs/06_outbounds.json`
  - `/opt/hiddify-manager/xray/configs/02_dns.json`
- template patched by the apply script:
  - `/opt/hiddify-manager/xray/configs/03_routing.json.j2`

Purpose:

- Keep Google Play domains before the server-side `forbidden_sites` CN route.
- Keep Microsoft Store and Windows Update delivery domains before the same CN route.
- Remove the bad `domain:xn--ngstr-lra8j.com` DNS host override if it appears.

Why this exists:

- `1d.tlu.dl.delivery.mp.microsoft.com:80` resolved to CDN IPs and was routed by
  server-side Xray to `forbidden_sites`, producing client-side `502`.
- `cdn.storeedgefd.dsx.mp.microsoft.com:443` later failed Store metadata fetches
  until StoreEdgeFD domains were added to the same server-side freedom exception.

Expected guard check:

```bash
/usr/local/sbin/hiddify-googleplay-route-guard --check
```

Expected output includes:

```text
google_play_route_before_forbidden=True
microsoft_delivery_route_before_forbidden=True
google_play_outbound=True
ngstr_hosts_override_removed=True
```

### HAProxy Timeout Self-Heal

Installed server files:

- `/usr/local/sbin/hiddify-haproxy-timeout-selfheal`
- `/etc/systemd/system/hiddify-haproxy-timeout-selfheal.service`
- `/etc/systemd/system/hiddify-haproxy-timeout-selfheal.path`
- patched files:
  - `/opt/hiddify-manager/haproxy/haproxy.cfg.j2`
  - `/opt/hiddify-manager/haproxy/haproxy.cfg`

Purpose:

- Keep Hiddify HAProxy `timeout client`, `timeout client-fin`, and `timeout server`
  at `180s`.
- Reapply the setting when Hiddify regenerates HAProxy config.

Why this exists:

- Long Codex compact/streaming requests were vulnerable to default HAProxy timeouts.

Expected config lines:

```bash
grep -n "timeout client\|timeout client-fin\|timeout server" \
  /opt/hiddify-manager/haproxy/haproxy.cfg \
  /opt/hiddify-manager/haproxy/haproxy.cfg.j2
```

Expected values:

```text
timeout client 180s
timeout client-fin 180s
timeout server 180s
```

## Reapply On A Server

From a local checkout:

```bash
scp -P 7649 scripts/ops/apply-hiddify-server-overrides.sh root@209.87.93.20:/tmp/
ssh -p 7649 root@209.87.93.20 'bash /tmp/apply-hiddify-server-overrides.sh'
```

For a different server, replace the SSH host and port. The script must run as root.

The script is idempotent. It creates backups under:

- `/opt/hiddify-manager/local-backups/codex-overrides`
- `/root/hiddify-googleplay-route-guard/backups`
- `/opt/hiddify-manager/local-backups/haproxy-timeout`

## Post-Apply Verification

Run:

```bash
/usr/local/sbin/hiddify-googleplay-route-guard --check
xray run -test -confdir /opt/hiddify-manager/xray/configs/
systemctl is-active hiddify-xray hiddify-haproxy hiddify-haproxy-timeout-selfheal.path
```

Then verify the Microsoft Store paths from a client using Hiddify:

```bash
curl -I --proxy http://127.0.0.1:12334 https://cdn.storeedgefd.dsx.mp.microsoft.com/
curl -r 0-0 --proxy http://127.0.0.1:12334 http://tlu.dl.delivery.mp.microsoft.com/
```

The exact Store download URLs change, so use a current Delivery Optimization URL when
debugging a real Store update.

## Notes

- Do not rely only on generated JSON files under `/opt/hiddify-manager/xray/configs`.
  Hiddify can regenerate them.
- The Xray systemd drop-in is the important runtime safety net because it patches the
  generated JSON before Xray starts.
- The HAProxy path unit is the runtime safety net for regenerated HAProxy config.
- Re-run `scripts/ops/apply-hiddify-server-overrides.sh` after Hiddify manager upgrades
  or server migration.
