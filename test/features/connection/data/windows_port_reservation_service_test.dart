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
     12334       12337     *
     50000       50059     *

* - Administered port exclusions.
""";

      expect(WindowsPortReservationService.parseExcludedPortRanges(output), [
        const PortRange(4928, 5027),
        const PortRange(12334, 12337),
        const PortRange(50000, 50059),
      ]);
    });

    test("computes only missing reservation segments", () {
      final missing = WindowsPortReservationService.missingSegments(
        reserved: const [PortRange(12334, 12337), PortRange(16756, 16756), PortRange(17078, 17078)],
        existing: const [PortRange(12334, 12335), PortRange(17078, 17078)],
      );

      expect(missing, const [PortRange(12336, 12337), PortRange(16756, 16756)]);
    });

    test("builds reservation commands for every Windows address family and protocol", () {
      final commands = WindowsPortReservationService.buildReservationCommands(const [
        PortReservation(family: "ipv4", protocol: "tcp", range: PortRange(12334, 12337)),
        PortReservation(family: "ipv6", protocol: "udp", range: PortRange(17078, 17078)),
      ]);

      expect(
        commands,
        containsAll([
          "netsh.exe int ipv4 add excludedportrange protocol=tcp startport=12334 numberofports=4 store=persistent",
          "netsh.exe int ipv6 add excludedportrange protocol=udp startport=17078 numberofports=1 store=persistent",
        ]),
      );
    });
  });
}
