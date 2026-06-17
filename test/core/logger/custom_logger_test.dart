import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/logger/custom_logger.dart';
import 'package:loggy/loggy.dart';

void main() {
  test('file log printer backs up existing log on init and flushes each record', () async {
    final dir = await Directory.systemTemp.createTemp('hiddify-file-log-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}app.log');
    await file.writeAsString('previous run');

    final printer = FileLogPrinter(file.path);
    printer.onLog(LogRecord(LogLevel.info, 'first line', 'test'));
    printer.dispose();

    final content = await file.readAsString();
    expect(content, isNot(contains('previous run')));
    expect(content, contains('[I] test: first line'));

    final backups = await dir
        .list()
        .where(
          (entity) =>
              entity is File &&
              entity.uri.pathSegments.last.startsWith('app.backup-') &&
              entity.uri.pathSegments.last.endsWith('.log'),
        )
        .cast<File>()
        .toList();
    expect(backups, hasLength(1));
    expect(await backups.single.readAsString(), 'previous run');
  });
}
