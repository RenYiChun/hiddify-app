import 'package:flutter_test/flutter_test.dart';
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
  ];

  test("enables bypass LAN by default", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWith((ref) => preferences)]);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.bypassLan), isTrue);
  });

  test("uses CN process direct defaults before the user customizes the list", () async {
    SharedPreferences.setMockInitialValues({"region": "cn"});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWith((ref) => preferences)]);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.region), Region.cn);
    expect(container.read(ConfigOptions.enableProcessDirectRules), isTrue);
    expect(container.read(ConfigOptions.processDirectRuleNames), isEmpty);
    expect(
      container.read(ConfigOptions.effectiveProcessDirectRuleNames),
      cnProcessDirectDefaults,
    );
  });

  test("applies CN process direct defaults after region changes before the user customizes the list", () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWith((ref) => preferences)]);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.region), Region.other);
    expect(container.read(ConfigOptions.processDirectRuleNames), isEmpty);

    await container.read(ConfigOptions.region.notifier).update(Region.cn);

    expect(
      container.read(ConfigOptions.singboxConfigOptions).processDirectRuleNames,
      cnProcessDirectDefaults,
    );
  });

  test("keeps an empty process direct list after the user clears it", () async {
    SharedPreferences.setMockInitialValues({"region": "cn", "process-direct-rule-names": ""});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWith((ref) => preferences)]);
    addTearDown(container.dispose);

    expect(container.read(ConfigOptions.processDirectRuleNames), isEmpty);
    expect(container.read(ConfigOptions.effectiveProcessDirectRuleNames), isEmpty);
  });
}
