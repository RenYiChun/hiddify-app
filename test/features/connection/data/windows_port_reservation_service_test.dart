import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/data/windows_port_reservation_service.dart';

void main() {
  group("WindowsPortReservationService", () {
    test("parses netsh excluded port ranges", () {
      const output = """
Protocol tcp Port Exclusion Ranges

Start Port    End Port
----------    --------
      4928        5027
     12434       12437     *
     50000       50059     *

* - Administered port exclusions.
""";

      expect(WindowsPortReservationService.parseExcludedPortRanges(output), [
        const PortRange(4928, 5027),
        const PortRange(12434, 12437),
        const PortRange(50000, 50059),
      ]);
    });

    test("computes only missing reservation segments", () {
      final missing = WindowsPortReservationService.missingSegments(
        reserved: const [PortRange(12434, 12437), PortRange(16757, 16757), PortRange(17079, 17079)],
        existing: const [PortRange(12434, 12435), PortRange(17079, 17079)],
      );

      expect(missing, const [PortRange(12436, 12437), PortRange(16757, 16757)]);
    });

    test("builds reservation commands for every Windows address family and protocol", () {
      final commands = WindowsPortReservationService.buildReservationCommands(const [
        PortReservation(family: "ipv4", protocol: "tcp", range: PortRange(12434, 12437)),
        PortReservation(family: "ipv6", protocol: "udp", range: PortRange(17079, 17079)),
      ]);

      expect(
        commands,
        containsAll([
          "netsh.exe int ipv4 add excludedportrange protocol=tcp startport=12434 numberofports=4 store=persistent",
          "netsh.exe int ipv6 add excludedportrange protocol=udp startport=17079 numberofports=1 store=persistent",
        ]),
      );
    });
  });
}
