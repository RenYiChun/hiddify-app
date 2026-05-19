import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';

void main() {
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
