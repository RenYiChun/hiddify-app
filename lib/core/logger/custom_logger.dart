// ignore_for_file: avoid_print

import 'dart:io';

import 'package:loggy/loggy.dart';
import 'package:path/path.dart' as p;

class ConsolePrinter extends LoggyPrinter {
  const ConsolePrinter({this.showColors = false});

  final bool showColors;

  static final _levelColors = {
    LogLevel.debug: AnsiColor(foregroundColor: AnsiColor.grey(0.5), italic: true),
    LogLevel.info: AnsiColor(foregroundColor: 35),
    LogLevel.warning: AnsiColor(foregroundColor: 214),
    LogLevel.error: AnsiColor(foregroundColor: 196),
  };

  @override
  void onLog(LogRecord record) {
    final colorize = showColors && stdout.supportsAnsiEscapes;
    final time = record.time.toIso8601String().split('T')[1];
    final callerFrame = record.callerFrame == null ? ' ' : ' (${record.callerFrame?.location}) ';

    final String logLevel;
    if (colorize) {
      logLevel = record.level.name.toUpperCase().padRight(8);
    } else {
      logLevel = "[${record.level.name.toUpperCase()}]".padRight(10);
    }

    final color = showColors ? levelColor(record.level) ?? AnsiColor() : AnsiColor();

    print(color('$time $logLevel [${record.loggerName}]$callerFrame${record.message}'));

    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
  }

  AnsiColor? levelColor(LogLevel level) {
    return _levelColors[level];
  }
}

class FileLogPrinter extends LoggyPrinter {
  FileLogPrinter(String filePath, {this.minLevel = LogLevel.debug}) : _logFile = File(filePath) {
    _logFile.parent.createSync(recursive: true);
    _backupExistingLog();
    _logFile.writeAsStringSync("");
  }

  final File _logFile;
  final LogLevel minLevel;

  @override
  void onLog(LogRecord record) {
    if (record.level.priority < minLevel.priority) return;

    final time = record.time.toIso8601String().split('T')[1];
    final buffer = StringBuffer()..writeln("$time - $record");
    if (record.error != null) {
      buffer.writeln(record.error);
    }
    if (record.stackTrace != null) {
      buffer.writeln(record.stackTrace);
    }
    _logFile.writeAsStringSync(buffer.toString(), mode: FileMode.append, flush: true);
  }

  void dispose() {}

  void _backupExistingLog() {
    try {
      if (!_logFile.existsSync() || _logFile.lengthSync() == 0) return;
      _logFile.copySync(_nextBackupFile().path);
    } on FileSystemException {
      // Keep startup behavior best-effort if the old log cannot be copied.
    }
  }

  File _nextBackupFile() {
    final baseName = p.basenameWithoutExtension(_logFile.path);
    final extension = p.extension(_logFile.path);
    final timestamp = _formatBackupTimestamp(DateTime.now());
    for (var i = 0; i < 1000; i++) {
      final suffix = i == 0 ? "" : "-$i";
      final candidate = File(p.join(_logFile.parent.path, "$baseName.backup-$timestamp$suffix$extension"));
      if (!candidate.existsSync()) return candidate;
    }
    return File(
      p.join(_logFile.parent.path, "$baseName.backup-$timestamp-${DateTime.now().microsecondsSinceEpoch}$extension"),
    );
  }

  String _formatBackupTimestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, "0");
    String three(int value) => value.toString().padLeft(3, "0");
    return "${time.year}${two(time.month)}${two(time.day)}-${two(time.hour)}${two(time.minute)}${two(time.second)}${three(time.millisecond)}";
  }
}
