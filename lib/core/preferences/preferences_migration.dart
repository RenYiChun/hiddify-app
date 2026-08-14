import 'package:hiddify/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesMigration with InfraLogger {
  PreferencesMigration({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  static const versionKey = "preferences_version";

  Future<void> migrate() async {
    final currentVersion = sharedPreferences.getInt(versionKey) ?? 0;

    final List<PreferencesMigrationStep> migrationSteps = [
      PreferencesVersion1Migration(sharedPreferences),
      PreferencesVersion2Migration(sharedPreferences),
      PreferencesVersion3Migration(sharedPreferences),
      PreferencesVersion4Migration(sharedPreferences),
      PreferencesVersion5Migration(sharedPreferences),
      PreferencesVersion6Migration(sharedPreferences),
      PreferencesVersion7Migration(sharedPreferences),
      PreferencesVersion8Migration(sharedPreferences),
    ];

    if (currentVersion == migrationSteps.length) {
      loggy.debug("already using the latest version (v$currentVersion)");
      return;
    }

    final stopWatch = Stopwatch()..start();
    loggy.debug("migrating from v[$currentVersion] to v[${migrationSteps.length}]");
    for (int i = currentVersion; i < migrationSteps.length; i++) {
      loggy.debug("step [$i](v${i + 1})");
      await migrationSteps[i].migrate();
      await sharedPreferences.setInt(versionKey, i + 1);
    }
    stopWatch.stop();
    loggy.debug("migration took [${stopWatch.elapsedMilliseconds}]ms");
  }
}

const _directDnsAddressKey = "direct-dns-address";
const _aliDnsDoHAddress = "https://223.5.5.5/dns-query";
const _aliDnsTcpAddress = "tcp://223.5.5.5";
const _aliDnsDomainDoHAddress = "https://dns.alidns.com/dns-query";

class PreferencesVersion2Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion2Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getString(_directDnsAddressKey) case final String directDnsAddress
        when _isLegacyAliDnsAddress(directDnsAddress)) {
      loggy.debug("changing direct DNS from [$directDnsAddress] to [$_aliDnsTcpAddress]");
      await sharedPreferences.setString(_directDnsAddressKey, _aliDnsTcpAddress);
    }
  }

  bool _isLegacyAliDnsAddress(String directDnsAddress) {
    final value = directDnsAddress.trim().toLowerCase();
    return value == "223.5.5.5" ||
        value == "udp://223.5.5.5" ||
        value == "tcp://223.5.5.5" ||
        value == _aliDnsDoHAddress ||
        value == _aliDnsDomainDoHAddress;
  }
}

class PreferencesVersion3Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion3Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getString(_directDnsAddressKey) case final String directDnsAddress
        when _isAliDnsDoHAddress(directDnsAddress)) {
      loggy.debug("changing direct DNS from [$directDnsAddress] to [$_aliDnsTcpAddress]");
      await sharedPreferences.setString(_directDnsAddressKey, _aliDnsTcpAddress);
    }
  }

  bool _isAliDnsDoHAddress(String directDnsAddress) {
    final value = directDnsAddress.trim().toLowerCase();
    return value == _aliDnsDoHAddress || value == _aliDnsDomainDoHAddress;
  }
}

class PreferencesVersion4Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion4Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getString(_directDnsAddressKey) case final String directDnsAddress
        when directDnsAddress.trim().toLowerCase() == _aliDnsDoHAddress) {
      loggy.debug("changing direct DNS from [$directDnsAddress] to [$_aliDnsTcpAddress]");
      await sharedPreferences.setString(_directDnsAddressKey, _aliDnsTcpAddress);
    }
  }
}

const _directRouteConnectionLimitKey = "direct-route-connection-limit";
const _proxyRouteConnectionLimitKey = "proxy-route-connection-limit";
const _dynamicDirectBypassTtlKey = "dynamic-direct-bypass-ttl";
const _dynamicDirectBypassMaxRoutesKey = "dynamic-direct-bypass-max-routes";

class PreferencesVersion5Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion5Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getInt(_directRouteConnectionLimitKey) case 512) {
      loggy.debug("changing direct route connection limit from [512] to [2048]");
      await sharedPreferences.setInt(_directRouteConnectionLimitKey, 2048);
    }
    if (sharedPreferences.getInt(_proxyRouteConnectionLimitKey) case 128) {
      loggy.debug("changing proxy route connection limit from [128] to [256]");
      await sharedPreferences.setInt(_proxyRouteConnectionLimitKey, 256);
    }
  }
}

class PreferencesVersion6Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion6Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getInt(_dynamicDirectBypassTtlKey) case 1800) {
      loggy.debug("changing dynamic direct bypass ttl from [1800] to [86400]");
      await sharedPreferences.setInt(_dynamicDirectBypassTtlKey, 86400);
    }
    if (sharedPreferences.getInt(_dynamicDirectBypassMaxRoutesKey) case 512) {
      loggy.debug("changing dynamic direct bypass max routes from [512] to [2048]");
      await sharedPreferences.setInt(_dynamicDirectBypassMaxRoutesKey, 2048);
    }
  }
}

class PreferencesVersion7Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion7Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getInt(_proxyRouteConnectionLimitKey) case final int limit
        when limit == 128 || limit == 256) {
      loggy.debug("changing proxy route connection limit from [$limit] to [512]");
      await sharedPreferences.setInt(_proxyRouteConnectionLimitKey, 512);
    }
  }
}

const _processStableProxyExcludedOutboundKeywordsKey = "process-stable-proxy-excluded-outbound-keywords";
const _hardenedProcessStableProxyExcludedOutboundKeywords =
    "naive;quic;tuic;xhttp;httpupgrade; § 80;ssh;hysteria;mieru;wireguard";

class PreferencesVersion8Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion8Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getString(_processStableProxyExcludedOutboundKeywordsKey) case final String keywords
        when _isLegacyProcessStableProxyExclusions(keywords)) {
      loggy.debug("hardening the legacy process stable proxy exclusions");
      await sharedPreferences.setString(
        _processStableProxyExcludedOutboundKeywordsKey,
        _hardenedProcessStableProxyExcludedOutboundKeywords,
      );
    }
  }

  bool _isLegacyProcessStableProxyExclusions(String value) {
    final keywords = value
        .split(";")
        .map((keyword) => keyword.trim().toLowerCase())
        .where((keyword) => keyword.isNotEmpty)
        .toList();
    return keywords.length == 3 && keywords[0] == "naive" && keywords[1] == "quic" && keywords[2] == "tuic";
  }
}

abstract interface class PreferencesMigrationStep {
  PreferencesMigrationStep(this.sharedPreferences);

  final SharedPreferences sharedPreferences;

  Future<void> migrate();
}

class PreferencesVersion1Migration extends PreferencesMigrationStep with InfraLogger {
  PreferencesVersion1Migration(super.sharedPreferences);

  @override
  Future<void> migrate() async {
    if (sharedPreferences.getString("service-mode") case final String serviceMode) {
      final newMode = switch (serviceMode) {
        "proxy" || "system-proxy" || "vpn" => serviceMode,
        "systemProxy" => "system-proxy",
        "tun" => "vpn",
        _ => PlatformUtils.isDesktop ? "system-proxy" : "vpn",
      };
      loggy.debug("changing service-mode from [$serviceMode] to [$newMode]");
      await sharedPreferences.setString("service-mode", newMode);
    }

    if (sharedPreferences.getString("ipv6-mode") case final String ipv6Mode) {
      loggy.debug("changing ipv6-mode from [$ipv6Mode] to [${_ipv6Mapper(ipv6Mode)}]");
      await sharedPreferences.setString("ipv6-mode", _ipv6Mapper(ipv6Mode));
    }

    if (sharedPreferences.getString("remote-domain-dns-strategy") case final String remoteDomainStrategy) {
      loggy.debug(
        "changing [remote-domain-dns-strategy] = [$remoteDomainStrategy] to [remote-dns-domain-strategy] = [${_domainStrategyMapper(remoteDomainStrategy)}]",
      );
      await sharedPreferences.remove("remote-domain-dns-strategy");
      await sharedPreferences.setString("remote-dns-domain-strategy", _domainStrategyMapper(remoteDomainStrategy));
    }

    if (sharedPreferences.getString("direct-domain-dns-strategy") case final String directDomainStrategy) {
      loggy.debug(
        "changing [direct-domain-dns-strategy] = [$directDomainStrategy] to [direct-dns-domain-strategy] = [${_domainStrategyMapper(directDomainStrategy)}]",
      );
      await sharedPreferences.remove("direct-domain-dns-strategy");
      await sharedPreferences.setString("direct-dns-domain-strategy", _domainStrategyMapper(directDomainStrategy));
    }

    if (sharedPreferences.getInt("localDns-port") case final int directPort) {
      loggy.debug("changing [localDns-port] to [direct-port]");
      await sharedPreferences.remove("localDns-port");
      await sharedPreferences.setInt("direct-port", directPort);
    }

    await sharedPreferences.remove("execute-config-as-is");
    await sharedPreferences.remove("enable-tun");
    await sharedPreferences.remove("set-system-proxy");

    await sharedPreferences.remove("cron_profiles_update");
  }

  String _ipv6Mapper(String persisted) => switch (persisted) {
    "ipv4_only" || "prefer_ipv4" || "prefer_ipv4" || "ipv6_only" => persisted,
    "disable" => "ipv4_only",
    "enable" => "prefer_ipv4",
    "prefer" => "prefer_ipv6",
    "only" => "ipv6_only",
    _ => "ipv4_only",
  };

  String _domainStrategyMapper(String persisted) => switch (persisted) {
    "ipv4_only" || "prefer_ipv4" || "prefer_ipv4" || "ipv6_only" => persisted,
    "auto" => "",
    "preferIpv6" => "prefer_ipv6",
    "preferIpv4" => "prefer_ipv4",
    "ipv4Only" => "ipv4_only",
    "ipv6Only" => "ipv6_only",
    _ => "",
  };
}
