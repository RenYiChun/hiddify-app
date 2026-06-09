import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/model/optional_range.dart';
import 'package:hiddify/features/log/model/log_level.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';

void main() {
  test("serializes route connection limits", () {
    const options = SingboxConfigOption(
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
      directDnsDomainStrategy: DomainStrategy.ipv4Only,
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
      processDirectRuleNames: ["WXWork.exe", "WeChat.exe"],
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

    final json = options.toJson();
    expect(json["direct-route-connection-limit"], 512);
    expect(json["proxy-route-connection-limit"], 128);
    expect(json["enable-process-direct-rules"], true);
    expect(json["process-direct-rule-names"], ["WXWork.exe", "WeChat.exe"]);
    expect(json["enable-process-stable-proxy-rules"], true);
    expect(json["process-stable-proxy-rule-names"], ["codex.exe"]);
    expect(json["process-stable-proxy-excluded-outbound-keywords"], ["naive", "quic", "tuic"]);
    expect(json["enable-dynamic-direct-bypass"], true);
    expect(json.containsKey("dynamic-direct-bypass-threshold"), false);
    expect(json["dynamic-direct-bypass-ttl"], 900);
    expect(json["dynamic-direct-bypass-max-routes"], 128);
    expect(json["dynamic-direct-bypass-max-routes-per-host"], 16);
    expect(SingboxConfigOption.fromJson(json).directRouteConnectionLimit, 512);
    expect(SingboxConfigOption.fromJson(json).proxyRouteConnectionLimit, 128);
    expect(SingboxConfigOption.fromJson(json).enableProcessDirectRules, true);
    expect(SingboxConfigOption.fromJson(json).processDirectRuleNames, ["WXWork.exe", "WeChat.exe"]);
    expect(SingboxConfigOption.fromJson(json).enableProcessStableProxyRules, true);
    expect(SingboxConfigOption.fromJson(json).processStableProxyRuleNames, ["codex.exe"]);
    expect(SingboxConfigOption.fromJson(json).processStableProxyExcludedOutboundKeywords, ["naive", "quic", "tuic"]);
    expect(SingboxConfigOption.fromJson(json).enableDynamicDirectBypass, true);
    expect(SingboxConfigOption.fromJson(json).dynamicDirectBypassTtl, const Duration(minutes: 15));
    expect(SingboxConfigOption.fromJson(json).dynamicDirectBypassMaxRoutes, 128);
    expect(SingboxConfigOption.fromJson(json).dynamicDirectBypassMaxRoutesPerHost, 16);
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
