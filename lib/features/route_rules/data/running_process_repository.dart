import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

final runningProcessRepositoryProvider = Provider<RunningProcessRepository>((ref) => RunningProcessRepository());

final runningProcessesProvider = FutureProvider.autoDispose<List<RunningProcess>>((ref) {
  return ref.watch(runningProcessRepositoryProvider).listRunningProcesses();
});

class RunningProcess {
  const RunningProcess({required this.name, required this.pid, this.path});

  final String name;
  final int? pid;
  final String? path;
}

class RunningProcessRepository {
  Future<List<RunningProcess>> listRunningProcesses() async {
    if (!Platform.isWindows) return [];

    const command =
        'Get-CimInstance Win32_Process | '
        'Where-Object { \$_.Name } | '
        'Select-Object Name,ProcessId,ExecutablePath | '
        'ConvertTo-Json -Compress';
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      command,
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        const ['Get-CimInstance Win32_Process'],
        '${result.stderr}',
        result.exitCode,
      );
    }

    return parseRunningProcessesJson('${result.stdout}');
  }
}

List<RunningProcess> parseRunningProcessesJson(String output) {
  final trimmedOutput = output.trim();
  if (trimmedOutput.isEmpty) return [];

  final decoded = jsonDecode(trimmedOutput);
  final items = switch (decoded) {
    final List<dynamic> list => list,
    final Map<String, dynamic> map => [map],
    _ => const <dynamic>[],
  };

  final processesByName = <String, RunningProcess>{};
  for (final item in items) {
    if (item is! Map) continue;

    final name = _readString(item['Name']);
    if (name == null) continue;

    final normalizedName = name.toLowerCase();
    processesByName.putIfAbsent(
      normalizedName,
      () => RunningProcess(name: name, pid: _readInt(item['ProcessId']), path: _readString(item['ExecutablePath'])),
    );
  }

  return processesByName.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

List<Object> buildRunningProcessSelectionItems({
  required List<RunningProcess> runningProcesses,
  required List<String> selectedProcessNames,
  String searchQuery = '',
}) {
  final normalizedQuery = searchQuery.trim().toLowerCase();
  if (normalizedQuery.isNotEmpty) {
    return runningProcesses
        .where((process) {
          final path = process.path?.toLowerCase() ?? '';
          return process.name.toLowerCase().contains(normalizedQuery) || path.contains(normalizedQuery);
        })
        .cast<Object>()
        .toList();
  }

  final runningProcessNames = runningProcesses.map((process) => process.name.toLowerCase()).toSet();
  final missingSelectedProcesses = selectedProcessNames.where(
    (name) => !runningProcessNames.contains(name.toLowerCase()),
  );
  final sortedProcesses = runningProcesses.toList()
    ..sort((a, b) {
      final selectedIndexA = selectedProcessNames.indexWhere((name) => name.toLowerCase() == a.name.toLowerCase());
      final selectedIndexB = selectedProcessNames.indexWhere((name) => name.toLowerCase() == b.name.toLowerCase());

      if (selectedIndexA == -1 && selectedIndexB == -1) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (selectedIndexA == -1) return 1;
      if (selectedIndexB == -1) return -1;
      return selectedIndexA.compareTo(selectedIndexB);
    });

  return [...missingSelectedProcesses, ...sortedProcesses];
}

String? _readString(dynamic value) {
  final stringValue = value?.toString().trim();
  if (stringValue == null || stringValue.isEmpty) return null;
  return stringValue;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}
