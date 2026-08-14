import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const cnProcessDirectDefaults = [
    "crashpad_handler.exe",
    "FlutterPlugins.exe",
    "WeChatOCR.exe",
    "WeMail.exe",
    "WXDrive_x64.exe",
    "WXWork.exe",
    "WXWorkWeb.exe",
    "WXWorkXNet.exe",
    "Weixin.exe",
    "DingTalk.exe",
    "DingTalkHelper.exe",
    "微信开发者工具.exe",
  ];
  const codexStableProxyDefaults = [
    "Codex.exe",
    "codex.exe",
    "codex-acp-x64-windows.exe",
    "codex-x86_64-pc-windows-msvc.exe",
  ];

  test("enables bypass LAN by default", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.bypassLan), isTrue);
  });

  test("keeps LAN sharing password private and in config options", () async {
    SharedPreferences.setMockInitialValues({"lan_sharing_password": "secret"});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(ConfigOptions.privatePreferencesKeys, contains("lan-sharing-password"));
    expect(container.read(ConfigOptions.lanSharingPassword), "secret");
    expect(container.read(ConfigOptions.singboxConfigOptions).lanSharingPassword, "secret");
  });

  test("uses CN process direct defaults before the user customizes the list", () async {
    SharedPreferences.setMockInitialValues({"region": "cn"});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.region), Region.cn);
    expect(container.read(ConfigOptions.enableProcessDirectRules), isTrue);
    expect(container.read(ConfigOptions.processDirectRuleNames), isEmpty);
    expect(container.read(ConfigOptions.effectiveProcessDirectRuleNames), cnProcessDirectDefaults);
  });

  test("applies CN process direct defaults after region changes before the user customizes the list", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.region), Region.other);
    expect(container.read(ConfigOptions.processDirectRuleNames), isEmpty);

    await container.read(ConfigOptions.region.notifier).update(Region.cn);

    expect(container.read(ConfigOptions.singboxConfigOptions).processDirectRuleNames, cnProcessDirectDefaults);
  });

  test("keeps the required WeChat DevTools process direct after the user clears the list", () async {
    SharedPreferences.setMockInitialValues({"region": "cn", "process-direct-rule-names": ""});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.processDirectRuleNames), isEmpty);
    expect(container.read(ConfigOptions.effectiveProcessDirectRuleNames), requiredCnProcessDirectRuleNames);
  });

  test("uses Codex process stable proxy defaults before the user customizes the list", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.enableProcessStableProxyRules), isTrue);
    expect(container.read(ConfigOptions.processStableProxyRuleNames), isEmpty);
    expect(container.read(ConfigOptions.effectiveProcessStableProxyRuleNames), codexStableProxyDefaults);
    expect(container.read(ConfigOptions.singboxConfigOptions).processStableProxyRuleNames, codexStableProxyDefaults);
    expect(container.read(ConfigOptions.singboxConfigOptions).processStableProxyExcludedOutboundKeywords, [
      "naive",
      "quic",
      "tuic",
      "xhttp",
      "httpupgrade",
      " § 80",
      "ssh",
      "hysteria",
      "mieru",
      "wireguard",
    ]);
  });

  test("keeps an empty process stable proxy list after the user clears it", () async {
    SharedPreferences.setMockInitialValues({"process-stable-proxy-rule-names": ""});
    final preferences = await SharedPreferences.getInstance();
    final container = await _createContainer(preferences);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.processStableProxyRuleNames), isEmpty);
    expect(container.read(ConfigOptions.effectiveProcessStableProxyRuleNames), isEmpty);
  });
}

Future<ProviderContainer> _createContainer(SharedPreferences preferences) async {
  final dir = await Directory.systemTemp.createTemp('config-options-');
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => preferences),
      appDirectoriesProvider.overrideWith(() => _TestAppDirectories((baseDir: dir, workingDir: dir, tempDir: dir))),
    ],
  );
  await container.read(appDirectoriesProvider.future);
  return container;
}

class _TestAppDirectories extends AppDirectories {
  _TestAppDirectories(this.directories);

  final Directories directories;

  @override
  Future<Directories> build() async => directories;
}
