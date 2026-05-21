import 'dart:io';

import 'package:path/path.dart' as p;

class LogPathResolver {
  const LogPathResolver(this._workingDir);

  final Directory _workingDir;

  Directory get directory => _workingDir;

  Directory get dataDirectory => Directory(p.join(directory.path, "data"));

  File coreFile() {
    return File(p.join(dataDirectory.path, "box.log"));
  }

  File urlTestFile() {
    return File(p.join(dataDirectory.path, "url-test.log"));
  }

  File appFile() {
    return File(p.join(dataDirectory.path, "app.log"));
  }

  Future<void> cleanupLegacyTopLevelLogs() async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!_isLegacyTopLevelLog(fileName)) continue;
      try {
        final length = await entity.length();
        if (length == 0) {
          await entity.delete();
          continue;
        }
        if (fileName == "app.log") {
          await dataDirectory.create(recursive: true);
          await entity.rename(_nextLegacyAppArchiveFile().path);
        }
      } on FileSystemException {
        continue;
      }
    }
    if (!await dataDirectory.exists()) return;
    await for (final entity in dataDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (!_isDataRootEmptyLog(fileName)) continue;
      try {
        if (await entity.length() == 0) {
          await entity.delete();
        }
      } on FileSystemException {
        continue;
      }
    }
  }

  bool _isLegacyTopLevelLog(String fileName) {
    return fileName == "app.log" ||
        fileName == "box.log" ||
        (fileName.startsWith("CrashReport-") && fileName.endsWith(".log"));
  }

  bool _isDataRootEmptyLog(String fileName) {
    return fileName.startsWith("CrashReport-") && fileName.endsWith(".log");
  }

  File _nextLegacyAppArchiveFile() {
    final first = File(p.join(dataDirectory.path, "app.legacy.log"));
    if (!first.existsSync()) return first;
    for (var i = 1; i < 1000; i++) {
      final candidate = File(p.join(dataDirectory.path, "app.legacy-$i.log"));
      if (!candidate.existsSync()) return candidate;
    }
    return File(p.join(dataDirectory.path, "app.legacy-${DateTime.now().millisecondsSinceEpoch}.log"));
  }
}
