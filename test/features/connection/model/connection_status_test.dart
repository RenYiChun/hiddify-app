import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';

void main() {
  group("ConnectionStatus.withConnectivityDelay", () {
    test("keeps connected only after a successful delay result", () {
      expect(const Connected().withConnectivityDelay(167), const Connected());
    });

    test("presents connected as connecting while delay is missing or timed out", () {
      expect(const Connected().withConnectivityDelay(0), const Connecting());
      expect(const Connected().withConnectivityDelay(65000), const Connecting());
      expect(const Connected().withConnectivityDelay(65001), const Connecting());
    });

    test("does not rewrite non-connected states", () {
      expect(const Disconnected().withConnectivityDelay(167), const Disconnected());
      expect(const Connecting().withConnectivityDelay(167), const Connecting());
      expect(const Disconnecting().withConnectivityDelay(167), const Disconnecting());
    });
  });
}
