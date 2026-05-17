import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/singbox/model/core_status.dart';

void main() {
  group("coreStatusListenerStream", () {
    test("does not append stopped when the listener stream closes", () async {
      final statuses = coreStatusListenerStream(Stream.fromIterable([CoreInfoResponse(coreState: CoreStates.STARTED)]));

      await expectLater(statuses, emitsInOrder([const CoreStatus.started(), emitsDone]));
    });

    test("keeps explicit stopped events from the core", () async {
      final statuses = coreStatusListenerStream(
        Stream.fromIterable([
          CoreInfoResponse(coreState: CoreStates.STARTED),
          CoreInfoResponse(coreState: CoreStates.STOPPED),
        ]),
      );

      await expectLater(
        statuses,
        emitsInOrder([const CoreStatus.started(), const CoreStatus.stopped(message: ""), emitsDone]),
      );
    });
  });
}
