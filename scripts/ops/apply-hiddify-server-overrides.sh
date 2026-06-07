#!/usr/bin/env bash
set -Eeuo pipefail

HIDDIFY_MANAGER_DIR="${HIDDIFY_MANAGER_DIR:-/opt/hiddify-manager}"
HAPROXY_TIMEOUT_SECONDS="${HIDDIFY_HAPROXY_TIMEOUT_SECONDS:-180}"
BACKUP_ROOT="${HIDDIFY_OVERRIDE_BACKUP_ROOT:-/opt/hiddify-manager/local-backups/codex-overrides}"

log() {
    printf '[hiddify-overrides] %s\n' "$*"
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log "must run as root"
        exit 1
    fi
}

require_hiddify_manager() {
    if [[ ! -d "$HIDDIFY_MANAGER_DIR" ]]; then
        log "missing Hiddify manager directory: $HIDDIFY_MANAGER_DIR"
        exit 2
    fi
}

backup_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local backup_dir
    backup_dir="${BACKUP_ROOT}/$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$backup_dir"
    cp -a "$file" "${backup_dir}/$(basename "$file").bak"
}

install_xray_route_guard() {
    local guard_tmp
    guard_tmp="$(mktemp)"
    cat >"$guard_tmp" <<'PY'
#!/usr/bin/env python3
import argparse
import json
import shutil
import sys
import time
from pathlib import Path

ROOT = Path('/opt/hiddify-manager/xray/configs')
ROUTING = ROOT / '03_routing.json'
OUTBOUNDS = ROOT / '06_outbounds.json'
DNS = ROOT / '02_dns.json'
BACKUP_ROOT = Path('/root/hiddify-googleplay-route-guard/backups')

DOMAINS = [
    'domain:gvt1.com',
    'domain:gvt2.com',
    'domain:googleapis.cn',
    'domain:xn--ngstr-lra8j.com',
    'domain:googleapis.com',
    'domain:googleusercontent.com',
    'domain:android.clients.google.com',
    'domain:play.googleapis.com',
    'domain:play-fe.googleapis.com',
    'domain:ggpht.com',
    'domain:googlevideo.com',
]

MICROSOFT_DELIVERY_DOMAINS = [
    'domain:delivery.mp.microsoft.com',
    'domain:dl.delivery.mp.microsoft.com',
    'domain:tlu.dl.delivery.mp.microsoft.com',
    'domain:delivery.microsoft.com',
    'domain:emdl.ws.microsoft.com',
    'domain:prod.do.dsp.mp.microsoft.com.edgekey.net',
    'domain:dcat-b-tlu-net.trafficmanager.net',
    'domain:bg.microsoft.map.fastly.net',
    'domain:windowsupdate.com',
    'domain:windowsupdate.microsoft.com',
    'domain:update.microsoft.com',
    'domain:download.windowsupdate.com',
    'domain:download.microsoft.com',
    'domain:displaycatalog.mp.microsoft.com',
    'domain:dsp.mp.microsoft.com',
    'domain:storeedge.microsoft.com',
    'domain:storeedgefd.dsx.mp.microsoft.com',
    'domain:cdn.storeedgefd.dsx.mp.microsoft.com',
]

GOOGLE_PLAY_ROUTE = {
    'type': 'field',
    'outboundTag': 'google_play_freedom',
    'domain': DOMAINS,
}

MICROSOFT_DELIVERY_ROUTE = {
    'type': 'field',
    'outboundTag': 'freedom',
    'domain': MICROSOFT_DELIVERY_DOMAINS,
}

GOOGLE_PLAY_OUTBOUND = {
    'tag': 'google_play_freedom',
    'protocol': 'freedom',
    'settings': {'domainStrategy': 'UseIP'},
}

_backup_dir = None


def load_json(path):
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def ensure_backup_dir():
    global _backup_dir
    if _backup_dir is None:
        _backup_dir = BACKUP_ROOT / time.strftime('%Y%m%d-%H%M%S')
        _backup_dir.mkdir(parents=True, exist_ok=True)
    return _backup_dir


def backup(path):
    dest = ensure_backup_dir() / path.name
    if not dest.exists():
        shutil.copy2(path, dest)


def write_json_if_changed(path, old_text, data):
    new_text = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    if new_text == old_text:
        return False
    backup(path)
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(new_text, encoding='utf-8')
    tmp.replace(path)
    return True


def patch_routing(apply):
    old_text = ROUTING.read_text(encoding='utf-8')
    data = json.loads(old_text)
    routing = data.setdefault('routing', {})
    rules = routing.setdefault('rules', [])

    def is_our_rule(rule):
        domains = set(rule.get('domain') or [])
        return (
            rule.get('outboundTag') == 'google_play_freedom'
            or ({'domain:xn--ngstr-lra8j.com', 'domain:googleapis.cn'} <= domains)
            or 'domain:delivery.mp.microsoft.com' in domains
        )

    filtered = [rule for rule in rules if not is_our_rule(rule)]
    insert_at = next((i for i, rule in enumerate(filtered) if rule.get('outboundTag') == 'forbidden_sites'), len(filtered))
    filtered.insert(insert_at, dict(GOOGLE_PLAY_ROUTE))
    filtered.insert(insert_at + 1, dict(MICROSOFT_DELIVERY_ROUTE))
    routing['rules'] = filtered

    if not apply:
        return old_text == json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    return write_json_if_changed(ROUTING, old_text, data)


def patch_outbounds(apply):
    old_text = OUTBOUNDS.read_text(encoding='utf-8')
    data = json.loads(old_text)
    outbounds = data.setdefault('outbounds', [])
    filtered = [outbound for outbound in outbounds if outbound.get('tag') != 'google_play_freedom']
    insert_at = next((i + 1 for i, outbound in enumerate(filtered) if outbound.get('tag') == 'freedom'), 0)
    filtered.insert(insert_at, dict(GOOGLE_PLAY_OUTBOUND))
    data['outbounds'] = filtered

    if not apply:
        return old_text == json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    return write_json_if_changed(OUTBOUNDS, old_text, data)


def patch_dns(apply):
    old_text = DNS.read_text(encoding='utf-8')
    data = json.loads(old_text)
    dns = data.setdefault('dns', {})
    hosts = dns.get('hosts')
    changed = False
    if isinstance(hosts, dict) and 'domain:xn--ngstr-lra8j.com' in hosts:
        hosts.pop('domain:xn--ngstr-lra8j.com', None)
        changed = True
        if not hosts:
            dns.pop('hosts', None)

    if not apply:
        return not changed
    if not changed:
        return False
    return write_json_if_changed(DNS, old_text, data)


def check_state():
    routing = load_json(ROUTING)
    rules = routing.get('routing', {}).get('rules', [])
    gp_index = next((i for i, rule in enumerate(rules)
                     if rule.get('outboundTag') == 'google_play_freedom'
                     and set(DOMAINS) <= set(rule.get('domain') or [])), None)
    microsoft_index = next((i for i, rule in enumerate(rules)
                            if rule.get('outboundTag') == 'freedom'
                            and set(MICROSOFT_DELIVERY_DOMAINS) <= set(rule.get('domain') or [])), None)
    forbidden_index = next((i for i, rule in enumerate(rules) if rule.get('outboundTag') == 'forbidden_sites'), None)

    outbounds = load_json(OUTBOUNDS).get('outbounds', [])
    has_outbound = any(outbound.get('tag') == 'google_play_freedom'
                       and outbound.get('protocol') == 'freedom'
                       and outbound.get('settings', {}).get('domainStrategy') == 'UseIP'
                       for outbound in outbounds)

    dns = load_json(DNS).get('dns', {})
    no_bad_host = 'domain:xn--ngstr-lra8j.com' not in (dns.get('hosts') or {})

    before_forbidden = gp_index is not None and (forbidden_index is None or gp_index < forbidden_index)
    microsoft_before_forbidden = microsoft_index is not None and (forbidden_index is None or microsoft_index < forbidden_index)
    return before_forbidden, microsoft_before_forbidden, has_outbound, no_bad_host


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    if args.apply:
        changes = []
        if patch_routing(True):
            changes.append('routing')
        if patch_outbounds(True):
            changes.append('outbounds')
        if patch_dns(True):
            changes.append('dns')
        print('changed=' + ','.join(changes) if changes else 'changed=none')

    before_forbidden, microsoft_before_forbidden, has_outbound, no_bad_host = check_state()
    print(f'google_play_route_before_forbidden={before_forbidden}')
    print(f'microsoft_delivery_route_before_forbidden={microsoft_before_forbidden}')
    print(f'google_play_outbound={has_outbound}')
    print(f'ngstr_hosts_override_removed={no_bad_host}')

    if args.check and not (before_forbidden and microsoft_before_forbidden and has_outbound and no_bad_host):
        return 1
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f'hiddify-googleplay-route-guard error: {exc}', file=sys.stderr)
        raise
PY

    backup_file /usr/local/sbin/hiddify-googleplay-route-guard
    install -o root -g root -m 0755 "$guard_tmp" /usr/local/sbin/hiddify-googleplay-route-guard
    rm -f "$guard_tmp"

    mkdir -p /etc/systemd/system/hiddify-xray.service.d
    backup_file /etc/systemd/system/hiddify-xray.service.d/10-googleplay-route-guard.conf
    cat >/etc/systemd/system/hiddify-xray.service.d/10-googleplay-route-guard.conf <<'UNIT'
[Service]
ExecStartPre=-/usr/local/sbin/hiddify-googleplay-route-guard --apply
UNIT
}

patch_xray_template_once() {
    local template="${HIDDIFY_MANAGER_DIR}/xray/configs/03_routing.json.j2"
    [[ -f "$template" ]] || {
        log "skip missing Xray template: $template"
        return 0
    }

    python3 - "$template" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
if 'domain:delivery.mp.microsoft.com' in text and 'domain:cdn.storeedgefd.dsx.mp.microsoft.com' in text:
    print('xray template already has Microsoft delivery override')
    raise SystemExit(0)

marker = "        {% if hconfigs['warp_mode'] != 'all' %}"
if marker not in text:
    print('warning: xray template insertion marker not found; runtime guard will still patch generated JSON')
    raise SystemExit(0)

block = '''        {
            "type": "field",
            "outboundTag": "freedom",
            "domain": [
              "domain:delivery.mp.microsoft.com",
              "domain:dl.delivery.mp.microsoft.com",
              "domain:tlu.dl.delivery.mp.microsoft.com",
              "domain:delivery.microsoft.com",
              "domain:emdl.ws.microsoft.com",
              "domain:prod.do.dsp.mp.microsoft.com.edgekey.net",
              "domain:dcat-b-tlu-net.trafficmanager.net",
              "domain:bg.microsoft.map.fastly.net",
              "domain:windowsupdate.com",
              "domain:windowsupdate.microsoft.com",
              "domain:update.microsoft.com",
              "domain:download.windowsupdate.com",
              "domain:download.microsoft.com",
              "domain:displaycatalog.mp.microsoft.com",
              "domain:dsp.mp.microsoft.com",
              "domain:storeedge.microsoft.com",
              "domain:storeedgefd.dsx.mp.microsoft.com",
              "domain:cdn.storeedgefd.dsx.mp.microsoft.com"
            ]
        },
'''
path.write_text(text.replace(marker, block + marker, 1), encoding='utf-8')
print('patched xray template Microsoft delivery override')
PY
}

install_haproxy_timeout_selfheal() {
    local script_tmp
    script_tmp="$(mktemp)"
    cat >"$script_tmp" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail

TIMEOUT_SECONDS="${HIDDIFY_HAPROXY_TIMEOUT_SECONDS:-180}"
HAPROXY_DIR="${HIDDIFY_HAPROXY_DIR:-/opt/hiddify-manager/haproxy}"
J2_FILE="${HAPROXY_DIR}/haproxy.cfg.j2"
CFG_FILE="${HAPROXY_DIR}/haproxy.cfg"
LOG_FILE="${HIDDIFY_HAPROXY_TIMEOUT_LOG:-/opt/hiddify-manager/log/system/haproxy_timeout_selfheal.log}"
BACKUP_DIR="${HIDDIFY_HAPROXY_TIMEOUT_BACKUP_DIR:-/opt/hiddify-manager/local-backups/haproxy-timeout}"
LOCK_FILE="${HIDDIFY_HAPROXY_TIMEOUT_LOCK:-/run/hiddify-haproxy-timeout-selfheal.lock}"
TIMEOUT_VALUE="${TIMEOUT_SECONDS}s"
PATCHED=0

log() {
    local message="$*"
    local ts
    ts="$(date '+%F %T %z')"
    printf '%s %s\n' "$ts" "$message"
    if [[ -n "${LOG_FILE}" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        printf '%s %s\n' "$ts" "$message" >>"$LOG_FILE" 2>/dev/null || true
    fi
}

if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
    log "invalid timeout seconds: ${TIMEOUT_SECONDS}"
    exit 2
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "another self-heal instance is running"
    exit 0
fi

require_timeout_line() {
    local file="$1"
    local key="$2"
    grep -Eq "^[[:space:]]*timeout[[:space:]]+${key}[[:space:]]+" "$file"
}

verify_timeout_value() {
    local file="$1"
    local key="$2"
    grep -Eq "^[[:space:]]*timeout[[:space:]]+${key}[[:space:]]+${TIMEOUT_VALUE}([[:space:]]*)$" "$file"
}

patch_file() {
    local file="$1"
    local tmp backup key

    if [[ ! -f "$file" ]]; then
        log "skip missing file=${file}"
        return 0
    fi

    for key in client client-fin server; do
        if ! require_timeout_line "$file" "$key"; then
            log "required timeout line missing file=${file} key=${key}"
            return 3
        fi
    done

    tmp="$(mktemp)"
    sed -E \
        -e "s/^([[:space:]]*timeout[[:space:]]+client[[:space:]]+).*/\\1${TIMEOUT_VALUE}/" \
        -e "s/^([[:space:]]*timeout[[:space:]]+client-fin[[:space:]]+).*/\\1${TIMEOUT_VALUE}/" \
        -e "s/^([[:space:]]*timeout[[:space:]]+server[[:space:]]+).*/\\1${TIMEOUT_VALUE}/" \
        "$file" >"$tmp"

    if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
        log "already correct file=${file} timeout=${TIMEOUT_VALUE}"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    backup="${BACKUP_DIR}/$(basename "$file").$(date '+%Y%m%d%H%M%S').bak"
    cp -a "$file" "$backup"
    cat "$tmp" >"$file"
    rm -f "$tmp"

    for key in client client-fin server; do
        if ! verify_timeout_value "$file" "$key"; then
            log "verification failed after patch file=${file} key=${key} expected=${TIMEOUT_VALUE}"
            return 4
        fi
    done

    PATCHED=1
    log "patched file=${file} timeout=${TIMEOUT_VALUE} backup=${backup}"
}

patch_file "$J2_FILE"
patch_file "$CFG_FILE"

if [[ "${HIDDIFY_HAPROXY_SELFHEAL_SKIP_VALIDATE:-0}" != "1" && -f "$CFG_FILE" ]]; then
    if /usr/sbin/haproxy -Ws -f "$HAPROXY_DIR/" -c -q -S /run/haproxy-master.sock; then
        log "haproxy config validation ok dir=${HAPROXY_DIR}"
    else
        log "haproxy config validation failed dir=${HAPROXY_DIR}"
        exit 5
    fi
fi

if [[ "$PATCHED" -eq 1 ]]; then
    if [[ "${HIDDIFY_HAPROXY_SELFHEAL_SKIP_RELOAD:-0}" == "1" ]]; then
        log "reload skipped by environment"
    elif systemctl is-active --quiet hiddify-haproxy; then
        if systemctl reload hiddify-haproxy; then
            log "hiddify-haproxy reloaded"
        else
            log "reload failed, trying restart"
            systemctl restart hiddify-haproxy
            log "hiddify-haproxy restarted"
        fi
    else
        log "hiddify-haproxy is not active; reload skipped"
    fi
else
    log "no timeout changes needed"
fi
BASH

    backup_file /usr/local/sbin/hiddify-haproxy-timeout-selfheal
    install -o root -g root -m 0755 "$script_tmp" /usr/local/sbin/hiddify-haproxy-timeout-selfheal
    rm -f "$script_tmp"

    backup_file /etc/systemd/system/hiddify-haproxy-timeout-selfheal.service
    cat >/etc/systemd/system/hiddify-haproxy-timeout-selfheal.service <<'UNIT'
[Unit]
Description=Self-heal Hiddify HAProxy timeout settings
Documentation=file:/usr/local/sbin/hiddify-haproxy-timeout-selfheal
After=hiddify-haproxy.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/hiddify-haproxy-timeout-selfheal
UNIT

    backup_file /etc/systemd/system/hiddify-haproxy-timeout-selfheal.path
    cat >/etc/systemd/system/hiddify-haproxy-timeout-selfheal.path <<'UNIT'
[Unit]
Description=Watch Hiddify HAProxy config for timeout self-heal

[Path]
PathChanged=/opt/hiddify-manager/haproxy/haproxy.cfg.j2
PathChanged=/opt/hiddify-manager/haproxy/haproxy.cfg
Unit=hiddify-haproxy-timeout-selfheal.service

[Install]
WantedBy=multi-user.target
UNIT
}

validate_xray_config() {
    if command -v xray >/dev/null 2>&1 && [[ -d "${HIDDIFY_MANAGER_DIR}/xray/configs" ]]; then
        xray run -test -confdir "${HIDDIFY_MANAGER_DIR}/xray/configs/" >/tmp/hiddify-xray-config-test.log 2>&1
        log "xray config validation ok"
    else
        log "skip xray validation: xray binary or config dir missing"
    fi
}

main() {
    require_root
    require_hiddify_manager

    log "installing Xray route guard"
    install_xray_route_guard
    patch_xray_template_once
    /usr/local/sbin/hiddify-googleplay-route-guard --apply --check

    log "installing HAProxy timeout self-heal"
    install_haproxy_timeout_selfheal
    HIDDIFY_HAPROXY_TIMEOUT_SECONDS="$HAPROXY_TIMEOUT_SECONDS" /usr/local/sbin/hiddify-haproxy-timeout-selfheal

    systemctl daemon-reload
    systemctl enable --now hiddify-haproxy-timeout-selfheal.path >/dev/null 2>&1 || true

    validate_xray_config
    if systemctl is-active --quiet hiddify-xray; then
        systemctl restart hiddify-xray
        log "hiddify-xray restarted"
    fi

    log "installed overrides"
    /usr/local/sbin/hiddify-googleplay-route-guard --check
    systemctl is-active hiddify-haproxy-timeout-selfheal.path hiddify-xray hiddify-haproxy 2>/dev/null || true
}

main "$@"
