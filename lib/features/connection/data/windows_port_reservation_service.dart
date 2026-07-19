import 'dart:convert';
import 'dart:io';

import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final windowsPortReservationServiceProvider = Provider<WindowsPortReservationService>(
  (ref) => WindowsPortReservationService(),
);

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

class WindowsPortReservationService with InfraLogger {
  WindowsPortReservationService({ProcessRunner? processRunner}) : _processRunner = processRunner ?? Process.run;

  static const addressFamilies = ["ipv4", "ipv6"];
  static const protocols = ["tcp", "udp"];
  static const reservedRanges = [PortRange(12434, 12437), PortRange(16757, 16757), PortRange(17079, 17079)];

  final ProcessRunner _processRunner;
  bool _promptedThisSession = false;

  Future<bool> ensureReserved({bool promptForElevation = true}) async {
    if (!Platform.isWindows) return true;

    final missing = await findMissingReservations();
    if (missing.isEmpty) {
      loggy.debug("Windows Hiddify port reservations are already present");
      return true;
    }

    loggy.warning(
      "Windows Hiddify port reservations missing: "
      "${missing.map((entry) => "${entry.family}/${entry.protocol}/${entry.range.start}-${entry.range.end}").join(", ")}",
    );

    if (!promptForElevation || _promptedThisSession) {
      return false;
    }

    _promptedThisSession = true;
    final elevated = await _runElevatedReservation(missing);
    if (!elevated) return false;

    final remaining = await findMissingReservations();
    if (remaining.isNotEmpty) {
      loggy.warning(
        "Windows Hiddify port reservations are still missing after elevation: "
        "${remaining.map((entry) => "${entry.family}/${entry.protocol}/${entry.range.start}-${entry.range.end}").join(", ")}",
      );
      return false;
    }

    loggy.info("Windows Hiddify port reservations applied");
    return true;
  }

  Future<List<PortReservation>> findMissingReservations() async {
    final missing = <PortReservation>[];
    for (final family in addressFamilies) {
      for (final protocol in protocols) {
        final result = await _processRunner("netsh.exe", [
          "int",
          family,
          "show",
          "excludedportrange",
          "protocol=$protocol",
        ]);
        if (result.exitCode != 0) {
          loggy.warning(
            "failed to inspect Windows excluded port ranges for $family/$protocol: "
            "${result.stderr}${result.stdout}",
          );
          missing.addAll(
            reservedRanges.map((range) => PortReservation(family: family, protocol: protocol, range: range)),
          );
          continue;
        }

        final existing = parseExcludedPortRanges("${result.stdout}\n${result.stderr}");
        missing.addAll(
          missingSegments(
            reserved: reservedRanges,
            existing: existing,
          ).map((range) => PortReservation(family: family, protocol: protocol, range: range)),
        );
      }
    }
    return missing;
  }

  Future<bool> _runElevatedReservation(List<PortReservation> reservations) async {
    final encodedCommand = _encodePowerShell(buildReservationScript(reservations));
    final launcher =
        """
try {
  \$process = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand','$encodedCommand') -Verb RunAs -WindowStyle Hidden -Wait -PassThru
  exit \$process.ExitCode
} catch {
  Write-Error \$_
  exit 1
}
""";

    final result = await _processRunner("powershell.exe", [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-Command",
      launcher,
    ]);
    if (result.exitCode != 0) {
      loggy.warning(
        "Windows Hiddify port reservation elevation failed or was canceled: "
        "exit=${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}",
      );
      return false;
    }
    return true;
  }

  static List<PortRange> parseExcludedPortRanges(String output) {
    final ranges = <PortRange>[];
    for (final line in const LineSplitter().convert(output)) {
      final match = RegExp(r'^\s*(\d+)\s+(\d+)\s*(\*)?').firstMatch(line);
      if (match == null) continue;
      ranges.add(PortRange(int.parse(match.group(1)!), int.parse(match.group(2)!)));
    }
    return ranges;
  }

  static List<PortRange> missingSegments({required List<PortRange> reserved, required List<PortRange> existing}) {
    final missing = <PortRange>[];
    for (final range in reserved) {
      var segments = [range];
      for (final existingRange in existing) {
        final next = <PortRange>[];
        for (final segment in segments) {
          if (existingRange.end < segment.start || existingRange.start > segment.end) {
            next.add(segment);
            continue;
          }
          if (existingRange.start > segment.start) {
            next.add(PortRange(segment.start, existingRange.start - 1));
          }
          if (existingRange.end < segment.end) {
            next.add(PortRange(existingRange.end + 1, segment.end));
          }
        }
        segments = next;
      }
      missing.addAll(segments);
    }
    return missing;
  }

  static List<String> buildReservationCommands(List<PortReservation> reservations) {
    return [
      for (final reservation in reservations)
        [
          "netsh.exe",
          "int",
          reservation.family,
          "add",
          "excludedportrange",
          "protocol=${reservation.protocol}",
          "startport=${reservation.range.start}",
          "numberofports=${reservation.range.length}",
          "store=persistent",
        ].join(" "),
    ];
  }

  static String buildReservationScript(List<PortReservation> reservations) {
    final commands = buildReservationCommands(reservations);
    return """
\$ErrorActionPreference = 'Continue'
\$failed = \$false
${commands.map((command) => """
& $command
if (\$LASTEXITCODE -ne 0) { \$failed = \$true }
""").join("\n")}
if (\$failed) { exit 2 }
exit 0
""";
  }

  static String _encodePowerShell(String script) {
    final bytes = <int>[];
    for (final codeUnit in script.codeUnits) {
      bytes.add(codeUnit & 0xff);
      bytes.add((codeUnit >> 8) & 0xff);
    }
    return base64Encode(bytes);
  }
}

class PortRange {
  const PortRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;

  @override
  bool operator ==(Object other) => other is PortRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => "PortRange($start, $end)";
}

class PortReservation {
  const PortReservation({required this.family, required this.protocol, required this.range});

  final String family;
  final String protocol;
  final PortRange range;

  @override
  bool operator ==(Object other) =>
      other is PortReservation && other.family == family && other.protocol == protocol && other.range == range;

  @override
  int get hashCode => Object.hash(family, protocol, range);

  @override
  String toString() => "PortReservation($family, $protocol, $range)";
}
