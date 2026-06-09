import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:hiddify/core/model/optional_range.dart';
import 'package:hiddify/features/log/model/log_level.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';

void main() {
  test('restart HTTP/2 transport close is recoverable', () {
    const recoverableError = GrpcError.unknown(
      'HTTP/2 error: Connection error: Connection is being forcefully terminated. (errorCode: 1)',
    );
    const realError = GrpcError.unknown('permission denied');

    expect(isRecoverableRestartGrpcDisconnect(recoverableError), isTrue);
    expect(isRecoverableRestartGrpcDisconnect(realError), isFalse);
  });

  test('runtime options force DNS strategies to IPv4-only when IPv6 is disabled', () {
    final warnings = <String>[];
    final normalized = normalizeCoreRuntimeOptions(
      _baseOptions.copyWith(
        ipv6Mode: IPv6Mode.disable,
        directDnsDomainStrategy: DomainStrategy.auto,
        remoteDnsDomainStrategy: DomainStrategy.auto,
      ),
      logWarning: warnings.add,
    );

    expect(normalized.directDnsDomainStrategy, DomainStrategy.ipv4Only);
    expect(normalized.remoteDnsDomainStrategy, DomainStrategy.ipv4Only);
    expect(warnings, hasLength(2));
  });

  test('runtime options preserve explicit DNS strategies', () {
    final normalized = normalizeCoreRuntimeOptions(
      _baseOptions.copyWith(
        ipv6Mode: IPv6Mode.disable,
        directDnsDomainStrategy: DomainStrategy.preferIpv4,
        remoteDnsDomainStrategy: DomainStrategy.ipv4Only,
      ),
    );

    expect(normalized.directDnsDomainStrategy, DomainStrategy.preferIpv4);
    expect(normalized.remoteDnsDomainStrategy, DomainStrategy.ipv4Only);
  });

  test('generated config diagnostics include process stable proxy candidates', () {
    final summary = summarizeProxyGroupOutboundsForDiagnostics([
      {
        "tag": "select",
        "type": "selector",
        "outbounds": ["lowest", "balance"],
      },
      {
        "tag": "process-stable-proxy §hide§",
        "type": "selector",
        "strategy": "lowest-delay",
        "outbounds": [
          "209.87.93.20 tls httpupgrade direct vless § 443 1",
          "209.87.93.20 tls grpc direct vmess § 443 1",
        ],
      },
    ]);

    expect(summary, contains("tag=process-stable-proxy §hide§"));
    expect(summary, contains("strategy=lowest-delay"));
    expect(summary, contains("209.87.93.20 tls httpupgrade direct vless § 443 1"));
  });
}

const _extraSecurity = SingboxExtraSecurityOption(
  mode: ChainMode.warp,
  warp: SingboxExtraSecurityWarpOption(licenseKey: ""),
  psiphon: SingboxExtraSecurityPsiphonOption(region: PsiphonRegion.auto, conduitPairingId: ""),
  profile: SingboxExtraSecurityProfileOption(id: null),
);

const _unblocker = SingboxUnblockerOption(
  mode: ChainMode.psiphon,
  warp: SingboxUnblockerWarpOption(
    licenseKey: "",
    cleanIp: "auto",
    cleanPort: 0,
    noise: OptionalRange(min: 1, max: 3),
    noiseSize: OptionalRange(min: 10, max: 30),
    noiseDelay: OptionalRange(min: 10, max: 30),
    noiseMode: "m4",
  ),
  psiphon: SingboxUnblockerPsiphonOption(region: PsiphonRegion.auto, conduitPairingId: ""),
  profile: SingboxUnblockerProfileOption(id: null),
);

const _baseOptions = SingboxConfigOption(
  region: "cn",
  balancerStrategy: BalancerStrategy.roundRobin,
  useXrayCoreWhenPossible: false,
  executeConfigAsIs: false,
  logLevel: LogLevel.warn,
  resolveDestination: true,
  ipv6Mode: IPv6Mode.disable,
  remoteDnsAddress: "tcp://8.8.8.8",
  remoteDnsDomainStrategy: DomainStrategy.auto,
  directDnsAddress: "tcp://223.5.5.5",
  directDnsDomainStrategy: DomainStrategy.auto,
  mixedPort: 12334,
  tproxyPort: 12335,
  directPort: 12337,
  redirectPort: 12336,
  tunImplementation: TunImplementation.gvisor,
  mtu: 9000,
  strictRoute: true,
  connectionTestUrl: "https://cp.cloudflare.com",
  urlTestInterval: Duration(minutes: 10),
  enableClashApi: true,
  clashApiPort: 16756,
  enableTun: true,
  setSystemProxy: false,
  bypassLan: true,
  allowConnectionFromLan: false,
  directRouteConnectionLimit: 512,
  proxyRouteConnectionLimit: 128,
  enableProcessDirectRules: true,
  processDirectRuleNames: ["WXWork.exe"],
  enableProcessStableProxyRules: true,
  processStableProxyRuleNames: ["codex.exe"],
  processStableProxyExcludedOutboundKeywords: ["naive", "quic", "tuic"],
  enableDynamicDirectBypass: true,
  dynamicDirectBypassTtl: Duration(minutes: 15),
  dynamicDirectBypassMaxRoutes: 128,
  dynamicDirectBypassMaxRoutesPerHost: 16,
  enableFakeDns: false,
  independentDnsCache: true,
  routeRule: <String, dynamic>{},
  tlsTricks: SingboxTlsTricks(
    enableFragment: false,
    fragmentSize: OptionalRange(min: 10, max: 30),
    fragmentSleep: OptionalRange(min: 2, max: 8),
    mixedSniCase: false,
    enablePadding: false,
    paddingSize: OptionalRange(min: 1, max: 1500),
  ),
  chainStatus: ChainStatus.off,
  extraSecurity: _extraSecurity,
  unblocker: _unblocker,
);
