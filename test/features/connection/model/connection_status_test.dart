import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';

void main() {
  group("ConnectionStatus.withConnectivityDelay", () {
    test("keeps connected independent of proxy delay result", () {
      expect(const Connected().withConnectivityDelay(167), const Connected());
      expect(const Connected().withConnectivityDelay(0), const Connected());
      expect(const Connected().withConnectivityDelay(65000), const Connected());
      expect(const Connected().withConnectivityDelay(65001), const Connected());
    });

    test("does not rewrite non-connected states", () {
      expect(const Disconnected().withConnectivityDelay(167), const Disconnected());
      expect(const Connecting().withConnectivityDelay(167), const Connecting());
      expect(const Disconnecting().withConnectivityDelay(167), const Disconnecting());
    });
  });

  group("ConnectionStatus.isConnected", () {
    test("treats only verified connected state as connected", () {
      expect(const Connected().isConnected, isTrue);
      expect(const Checking().isConnected, isFalse);
      expect(const OutboundUnavailable().isConnected, isFalse);
      expect(const CurrentOutboundUnavailable().isConnected, isFalse);
    });

    test("keeps lifecycle transition states non-connected", () {
      expect(const Disconnected().isConnected, isFalse);
      expect(const Connecting().isConnected, isFalse);
      expect(const Disconnecting().isConnected, isFalse);
    });
  });

  group("ConnectionStatus.isServiceRunning", () {
    test("treats core-started health states as running for control actions", () {
      expect(const Connected().isServiceRunning, isTrue);
      expect(const Checking().isServiceRunning, isTrue);
      expect(const OutboundUnavailable().isServiceRunning, isTrue);
      expect(const CurrentOutboundUnavailable().isServiceRunning, isTrue);
    });

    test("keeps stopped and lifecycle transition states non-running", () {
      expect(const Disconnected().isServiceRunning, isFalse);
      expect(const Connecting().isServiceRunning, isFalse);
      expect(const Disconnecting().isServiceRunning, isFalse);
    });
  });
}
