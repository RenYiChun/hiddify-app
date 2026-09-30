# 诊断报告：Hiddify 开代理后无法访问 google.com

- 时间：2026-09-20 08:58 – 09:15（GMT+8）
- 主机：Windows / WLAN 10.80.207.165
- 客户端：`C:\Program Files\Hiddify Custom\HiddifyCustom.exe`（PID 25884，二次打包版）
- 数据目录：`%APPDATA%\RenYiChun\HiddifyCustom\`
- 结论性质：**仅分析，未改动任何配置**

---

## 一、结论

**代理隧道本身是好的，节点访问 Google 完全正常。**
故障出在 **DNS 解析层**：配置把 `www.google.com` / `google.com` 的 DNS 查询显式交给了国内解析器
`dns-direct (tcp://223.5.5.5)`，而该网络下所有明文 DNS 对 google 的应答都是伪造的。
拿到伪造 IP 后，基于域名的分流规则（`domain_suffix: google.com` → 走代理）**匹配不上**，
流量被判给 `direct` 直连，去连一个不可达的伪造 IP，最终 `i/o timeout`。

---

## 二、可复核证据

### 1. 隧道正常（反面证据）

| 测试 | 命令 | 结果 |
|---|---|---|
| 经代理 + 域名访问 google | `curl -x http://127.0.0.1:12434 https://www.google.com/generate_204` | **HTTP 204**，6 次重试 6 次成功（443–3151 ms） |
| 经代理访问 gstatic | 同上 | **HTTP 204**，6/6 |
| 经代理 + 真实 Google IP + Host 头 | `142.251.155.119` | **HTTP 204** |
| 经代理访问对照站 | github / x.com / cloudflare | 200 / 200 / trace OK |
| 代理出口 | `cloudflare.com/cdn-cgi/trace` | `ip=209.87.93.20`，`colo=LAX`，`loc=US` |

→ 节点能到 Google，隧道没问题。

### 2. DNS 全面污染（实测，同一域名问多家解析器结果互相矛盾）

| DNS 服务器 | `www.google.com` 解析结果 | 真实归属 |
|---|---|---|
| 223.5.5.5（阿里，**配置正在用**） | `104.244.42.197` | Twitter 段 |
| 114.114.114.114 | `157.240.7.20` | Facebook 段 |
| 8.8.8.8 | `157.240.7.20` | Facebook 段（说明 8.8.8.8 也被劫持） |
| 1.1.1.1 | `104.244.42.197` | Twitter 段（同样被劫持） |
| 10.80.207.56（企业内网 DNS） | `185.45.5.35` | AS35995 Twitter，**TCP 443 实测不可达** |

对照：`www.bing.com` → `202.89.233.100`、`www.github.com` → `20.205.243.166`（正常）。
→ 只有被墙域名被伪造应答，是典型 DNS 污染。

### 3. 配置里的问题规则

`data\current-config.json` → `dns.rules` 第 2 条：

```json
{
  "domain": ["captive.apple.com", "209.87.93.20.sslip.io",
             "api.cloudflareclient.com", "cp.cloudflare.com",
             "www.google.com", "google.com"],
  "server": "dns-direct",          // = tcp://223.5.5.5
  "strategy": "ipv4_only",
  "rewrite_ttl": 86400             // 污染结果缓存 24 小时
}
```

同时：`route.default_domain_resolver = {"server":"dns-direct","strategy":"ipv4_only"}`
→ sing-box 自身需要解析域名时，也走这台被污染的解析器。

### 4. 内核日志实证

`data\box.log`：

```
ERROR connection: open connection to www.google.com:443 using outbound/direct[direct §hide§]:
      dial tcp 69.171.235.22:443: i/o timeout
WARN monitoring: outbound monitoring URL test summary:
      url=https://www.google.com/generate_204 total=38 success=0 failed=38 all_failed=true
WARN monitoring: outbound monitoring URL test summary:
      url=https://cp.cloudflare.com        total=38 success=0 failed=38 all_failed=true
```

两条探活 URL 里的域名，**恰好就是上面那条 dns-direct 规则里仅有的两个业务域名**
（`www.google.com`、`cp.cloudflare.com`）——互相印证：凡是走 `dns-direct` 的域名必挂。

### 5. 运行模式（`data\app.log` 的 core options 行）

```
enableTun=false, setSystemProxy=true, ipv6Mode=IPv6Mode.disable,
directDns=tcp://223.5.5.5, remoteDns=tcp://8.8.8.8,
dynamicDirectBypass=true, dynamicDirectBypassMode=all-direct,
dynamicDirectBypassTtl=86400s, fakeDns=false
```

- 已核实**没有 Wintun/TUN 网卡**，默认路由仍是 WLAN → 确认是纯系统代理模式。
- 系统代理已正确设置：`HKCU\...\Internet Settings` → `ProxyEnable=1`，
  `ProxyServer=http://127.0.0.1:12434`；该端口 HTTP 与 SOCKS5 均实测可用。

---

## 三、次要放大器

1. **未开 TUN**：仅靠系统代理，只有读 WinINET 设置的程序走代理。
   终端、curl、git、npm、Docker、WSL、部分桌面 App 全都绕过代理，自己解析 DNS → 拿到伪造 IP → 超时。
2. **`dynamicDirectBypass` 处于 `all-direct` 模式**，TTL 24 小时。
   已观察到 `data\dynamic-direct-bypass-routes.json` 中记录了 67 条直连旁路，
   其中包含 Google 系域名 `connectivitycheck.gstatic.com`（reason=direct）。
   该机制会把学到的"直连"路由复用一整天，可能把本该走代理的域名锁死在直连。
3. **规则集体量可疑**：`rules\geoip-cn.srs` 仅 73,646 字节、`geosite-cn.srs` 仅 40,617 字节，
   远小于公开规则集的常见体量，且二者均不含 `google` 字样（已做二进制字符串检查）。
   规则 [17] `rule_set: geoip-cn, geosite-cn → direct` 命中范围值得留意。
4. **节点单一且高负载**：全部出站只指向 `209.87.93.20`，实测该进程同时保持 **150+ 条**到该 IP 的连接
   （含 80/443 端口）。首次请求 google 曾超时、重试后恢复，与节点拥塞/瞬断特征一致。
5. **企业环境**：本机运行着 `Hillstone SecureConnectService`（企业 SSL VPN，虚拟网卡 Disconnected），
   内网 DNS 为 `10.80.207.56` / `172.20.50.1`。企业网络可能对翻墙流量做额外限制。

---

## 四、建议修复顺序（按杠杆从高到低）

1. **把 `www.google.com`、`google.com` 从 dns-direct 规则里移出**，改由 `dns-remote`（经代理查 8.8.8.8）解析。
   这是根因，改动最小、收益最大。
2. **`route.default_domain_resolver` 改为 `dns-remote`**，避免 sing-box 自身解析走污染 DNS。
3. **关闭 `dynamicDirectBypass`**（或从 `all-direct` 改为更保守的模式），
   并清理 `dynamic-direct-bypass-routes.json` 里已学习的直连路由；
   同时留意 `rewrite_ttl=86400` 会把污染的解析结果缓存一整天，改完需清缓存/重启内核。
4. **开启 TUN 模式**（`enableTun=true`）。这是系统代理模式下"部分程序不走代理"的根本解法。
   本机已有 `wintun.sys` 驱动，具备条件。
5. **更换/核实 `geoip-cn.srs`、`geosite-cn.srs`** 来源，排查这条 `direct` 规则的实际命中范围。
6. 复核规则 [4] 的进程直连名单（微信、企业微信、钉钉、微信开发者工具、`FlutterPlugins.exe`、
   `crashpad_handler.exe` 等）是否过宽——该规则按进程直连，**不区分目标域名**。

---

## 五、测试环境陷阱（避免误判）

WorkBuddy 会向子进程注入 `HTTP_PROXY=http://127.0.0.1:59989`（沙箱自身代理）。
它会**覆盖系统代理设置**，且对 google 返回 **502**。
实测：不显式指定 `-Proxy` 时，.NET 解析出的默认代理就是 `127.0.0.1:59989`。

→ 在 WorkBuddy 终端里跑 `curl google.com` 得到的失败**不代表 Hiddify 有问题**。
测试务必显式加 `-x http://127.0.0.1:12434` 或 `--noproxy '*'`。
