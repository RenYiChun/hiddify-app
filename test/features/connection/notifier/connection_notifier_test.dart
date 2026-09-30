import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';

void main() {
  group("ReconnectProgress", () {
    test("keeps reconnecting until a fresh core transition has recovered", () {
      var progress = const ReconnectProgress().start();
      expect(progress.observe(const Connected()).isReconnecting, isTrue);

      progress = progress.observe(const Disconnecting());
      expect(progress.observe(const Checking()).isReconnecting, isTrue);

      progress = progress.observe(const Connected());
      expect(progress.isReconnecting, isFalse);
      expect(progress.pending, 1);
      expect(progress.finish().pending, 0);
    });

    test("a later core transition or new request restores reconnecting", () {
      var progress = const ReconnectProgress().start().observe(const Connecting()).observe(const Connected());
      expect(progress.isReconnecting, isFalse);

      progress = progress.start();
      expect(progress.isReconnecting, isTrue);
      progress = progress.observe(const Disconnecting()).observe(const Connected());
      expect(progress.isReconnecting, isFalse);
      expect(progress.finish().finish().isReconnecting, isFalse);
    });
  });

  group("SingleCall", () {
    test("runs onIgnored when another call is already running", () async {
      final singleCall = SingleCall();
      final gate = Completer<void>();
      var ignored = false;

      final first = singleCall.run(() => gate.future, onIgnored: () {});
      await Future<void>.delayed(Duration.zero);

      await singleCall.run(
        () async {},
        onIgnored: () {
          ignored = true;
        },
      );

      gate.complete();
      await first;

      expect(ignored, isTrue);
    });
  });
}
