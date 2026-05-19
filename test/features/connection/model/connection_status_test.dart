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
    test("treats all core-started health states as connected for control actions", () {
      expect(const Connected().isConnected, isTrue);
      expect(const Checking().isConnected, isTrue);
      expect(const OutboundUnavailable().isConnected, isTrue);
      expect(const CurrentOutboundUnavailable().isConnected, isTrue);
    });

    test("keeps lifecycle transition states non-connected", () {
      expect(const Disconnected().isConnected, isFalse);
      expect(const Connecting().isConnected, isFalse);
      expect(const Disconnecting().isConnected, isFalse);
    });
  });
}
