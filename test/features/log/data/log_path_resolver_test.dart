import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/log/data/log_path_resolver.dart';

void main() {
  test('app log uses data directory and cleanup migrates legacy top-level app log', () async {
    final dir = await Directory.systemTemp.createTemp('hiddify-log-test-');
    addTearDown(() => dir.delete(recursive: true));

    final resolver = LogPathResolver(dir);
    await resolver.dataDirectory.create(recursive: true);
    final emptyLegacyCore = File('${dir.path}${Platform.pathSeparator}box.log');
    final legacyApp = File('${dir.path}${Platform.pathSeparator}app.log');
    final archivedLegacyApp = File('${resolver.dataDirectory.path}${Platform.pathSeparator}app.legacy.log');
    final emptyCrashReport = File('${dir.path}${Platform.pathSeparator}CrashReport-.log');
    final nonEmptyCrashReport = File('${dir.path}${Platform.pathSeparator}CrashReport-core.log');
    final emptyDataCrashReport = File('${resolver.dataDirectory.path}${Platform.pathSeparator}CrashReport-.log');
    final nonEmptyDataCrashReport = File('${resolver.dataDirectory.path}${Platform.pathSeparator}CrashReport-core.log');
    final appLog = resolver.appFile();

    await emptyLegacyCore.writeAsString('');
    await legacyApp.writeAsString('old app startup');
    await emptyCrashReport.writeAsString('');
    await nonEmptyCrashReport.writeAsString('panic details');
    await emptyDataCrashReport.writeAsString('');
    await nonEmptyDataCrashReport.writeAsString('panic details');

    await resolver.cleanupLegacyTopLevelLogs();
    await appLog.writeAsString('app startup');

    expect(appLog.path, contains('${Platform.pathSeparator}data${Platform.pathSeparator}app.log'));
    expect(await emptyLegacyCore.exists(), isFalse);
    expect(await legacyApp.exists(), isFalse);
    expect(await archivedLegacyApp.readAsString(), 'old app startup');
    expect(await emptyCrashReport.exists(), isFalse);
    expect(await nonEmptyCrashReport.readAsString(), 'panic details');
    expect(await emptyDataCrashReport.exists(), isFalse);
    expect(await nonEmptyDataCrashReport.readAsString(), 'panic details');
    expect(await appLog.readAsString(), 'app startup');
  });
}
