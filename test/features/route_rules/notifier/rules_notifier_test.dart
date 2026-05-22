import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test('stores route_rule.proto in the working directory', () async {
    final baseDir = await Directory.systemTemp.createTemp('route-rules-base-');
    final workingDir = await Directory.systemTemp.createTemp('route-rules-working-');
    final tempDir = await Directory.systemTemp.createTemp('route-rules-temp-');
    addTearDown(() async {
      await baseDir.delete(recursive: true);
      await workingDir.delete(recursive: true);
      await tempDir.delete(recursive: true);
    });

    final container = ProviderContainer(
      overrides: [
        appDirectoriesProvider.overrideWith(
          () => _TestAppDirectories((baseDir: baseDir, workingDir: workingDir, tempDir: tempDir)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appDirectoriesProvider.future);

    final notifier = container.read(rulesNotifierProvider.notifier);

    expect(notifier.file.path, '${workingDir.path}${Platform.pathSeparator}route_rule.proto');
  });

  test('reconnects the running service after route rules are updated', () async {
    final dir = await Directory.systemTemp.createTemp('route-rules-');
    addTearDown(() => dir.delete(recursive: true));
    final fakeConnection = _TestConnectionNotifier();
    final activeProfile = ProfileEntity.local(
      id: 'profile-1',
      active: true,
      name: 'Profile',
      lastUpdate: DateTime(2026),
    );
    final container = ProviderContainer(
      overrides: [
        appDirectoriesProvider.overrideWith(() => _TestAppDirectories((baseDir: dir, workingDir: dir, tempDir: dir))),
        serviceRunningProvider.overrideWith((ref) => true),
        activeProfileProvider.overrideWith(() => _TestActiveProfile(activeProfile)),
        connectionNotifierProvider.overrideWith(() => fakeConnection),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appDirectoriesProvider.future);

    await container
        .read(rulesNotifierProvider.notifier)
        .addRule(Rule(name: 'WeCom direct', outbound: Outbound.direct, processNames: ['WXWork.exe']));

    expect(fakeConnection.reconnectCount, 1);
    expect(fakeConnection.lastProfile, activeProfile);
  });
}

class _TestAppDirectories extends AppDirectories {
  _TestAppDirectories(this.directories);

  final Directories directories;

  @override
  Future<Directories> build() async => directories;
}

class _TestActiveProfile extends ActiveProfile {
  _TestActiveProfile(this.profile);

  final ProfileEntity profile;

  @override
  Stream<ProfileEntity?> build() => Stream.value(profile);
}

class _TestConnectionNotifier extends ConnectionNotifier {
  int reconnectCount = 0;
  ProfileEntity? lastProfile;

  @override
  Stream<ConnectionStatus> build() => Stream.value(const ConnectionStatus.connected());

  @override
  Future<void> reconnect(ProfileEntity? profile) async {
    reconnectCount++;
    lastProfile = profile;
  }
}
