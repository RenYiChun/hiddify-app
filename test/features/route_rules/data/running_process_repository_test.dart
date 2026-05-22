import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/route_rules/data/running_process_repository.dart';

void main() {
  test('parses and de-duplicates Windows process snapshot JSON', () {
    final processes = parseRunningProcessesJson('''
[
  {"Name":"Codex.exe","ProcessId":5976,"ExecutablePath":"C:\\\\Program Files\\\\Codex.exe"},
  {"Name":"codex.exe","ProcessId":17972,"ExecutablePath":"C:\\\\Program Files\\\\Codex Helper.exe"},
  {"Name":"WXWork.exe","ProcessId":2232,"ExecutablePath":"C:\\\\Program Files\\\\Tencent\\\\WeCom\\\\WXWork.exe"},
  {"Name":"","ProcessId":1,"ExecutablePath":null}
]
''');

    expect(processes.map((process) => process.name), ['Codex.exe', 'WXWork.exe']);
    expect(processes.first.pid, 5976);
    expect(processes.first.path, r'C:\Program Files\Codex.exe');
  });

  test('parses single-process JSON object', () {
    final processes = parseRunningProcessesJson(
      '{"Name":"Hiddify.exe","ProcessId":100,"ExecutablePath":"C:\\\\Hiddify\\\\Hiddify.exe"}',
    );

    expect(processes.single.name, 'Hiddify.exe');
  });

  test('builds selection list with selected missing processes first', () {
    const runningProcesses = [
      RunningProcess(name: 'WXWork.exe', pid: 1, path: r'C:\Tencent\WXWork.exe'),
      RunningProcess(name: 'Hiddify.exe', pid: 2, path: r'C:\Hiddify\Hiddify.exe'),
    ];

    final items = buildRunningProcessSelectionItems(
      runningProcesses: runningProcesses,
      selectedProcessNames: ['Codex.exe', 'Hiddify.exe'],
    );

    expect(items.first, 'Codex.exe');
    expect(items[1], isA<RunningProcess>().having((process) => process.name, 'name', 'Hiddify.exe'));
    expect(items.last, isA<RunningProcess>().having((process) => process.name, 'name', 'WXWork.exe'));
  });

  test('filters running processes by process name and executable path', () {
    const runningProcesses = [
      RunningProcess(name: 'WXWork.exe', pid: 1, path: r'C:\Tencent\WXWork.exe'),
      RunningProcess(name: 'Hiddify.exe', pid: 2, path: r'C:\Hiddify\Hiddify.exe'),
    ];

    final items = buildRunningProcessSelectionItems(
      runningProcesses: runningProcesses,
      selectedProcessNames: ['Codex.exe'],
      searchQuery: 'tencent',
    );

    expect(items, [runningProcesses.first]);
  });
}
