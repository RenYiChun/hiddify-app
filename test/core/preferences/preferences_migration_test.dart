import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/preferences/preferences_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group("PreferencesMigration", () {
    const directDnsAddressKey = "direct-dns-address";
    const aliDnsTcpAddress = "tcp://223.5.5.5";

    for (final legacyAliDnsAddress in [
      "223.5.5.5",
      "udp://223.5.5.5",
      "tcp://223.5.5.5",
      "https://223.5.5.5/dns-query",
      "https://dns.alidns.com/dns-query",
    ]) {
      test("migrates legacy AliDNS direct DNS [$legacyAliDnsAddress] to TCP", () async {
        SharedPreferences.setMockInitialValues({
          PreferencesMigration.versionKey: 1,
          directDnsAddressKey: legacyAliDnsAddress,
        });
        final preferences = await SharedPreferences.getInstance();

        await PreferencesMigration(sharedPreferences: preferences).migrate();

        expect(preferences.getString(directDnsAddressKey), aliDnsTcpAddress);
        expect(preferences.getInt(PreferencesMigration.versionKey), 6);
      });
    }

    test("migrates previously saved AliDNS domain DoH from v2 to TCP", () async {
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 2,
        directDnsAddressKey: "https://dns.alidns.com/dns-query",
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getString(directDnsAddressKey), aliDnsTcpAddress);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });

    test("migrates previously saved AliDNS IP DoH from v3 to TCP", () async {
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 3,
        directDnsAddressKey: "https://223.5.5.5/dns-query",
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getString(directDnsAddressKey), aliDnsTcpAddress);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });

    test("keeps non-AliDNS direct DNS unchanged during migrations", () async {
      const customDirectDnsAddress = "https://dns.cloudflare.com/dns-query";
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 1,
        directDnsAddressKey: customDirectDnsAddress,
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getString(directDnsAddressKey), customDirectDnsAddress);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });

    test("raises persisted route connection limits that still use the old defaults", () async {
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 4,
        "direct-route-connection-limit": 512,
        "proxy-route-connection-limit": 128,
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getInt("direct-route-connection-limit"), 2048);
      expect(preferences.getInt("proxy-route-connection-limit"), 256);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });

    test("preserves custom route connection limits during migration", () async {
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 4,
        "direct-route-connection-limit": 4096,
        "proxy-route-connection-limit": 512,
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getInt("direct-route-connection-limit"), 4096);
      expect(preferences.getInt("proxy-route-connection-limit"), 512);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });

    test("raises persisted dynamic bypass defaults for all-direct bypass mode", () async {
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 5,
        "dynamic-direct-bypass-ttl": 1800,
        "dynamic-direct-bypass-max-routes": 512,
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getInt("dynamic-direct-bypass-ttl"), 86400);
      expect(preferences.getInt("dynamic-direct-bypass-max-routes"), 2048);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });

    test("preserves custom dynamic bypass limits during migration", () async {
      SharedPreferences.setMockInitialValues({
        PreferencesMigration.versionKey: 5,
        "dynamic-direct-bypass-ttl": 7200,
        "dynamic-direct-bypass-max-routes": 4096,
      });
      final preferences = await SharedPreferences.getInstance();

      await PreferencesMigration(sharedPreferences: preferences).migrate();

      expect(preferences.getInt("dynamic-direct-bypass-ttl"), 7200);
      expect(preferences.getInt("dynamic-direct-bypass-max-routes"), 4096);
      expect(preferences.getInt(PreferencesMigration.versionKey), 6);
    });
  });
}
