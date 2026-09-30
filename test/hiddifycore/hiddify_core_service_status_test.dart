import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/singbox/model/core_status.dart';

void main() {
  group("FailedSelectedOutboundRetestGate", () {
    final start = DateTime(2026, 9, 29, 10, 22);
    final failed = [
      OutboundGroup(
        tag: "select",
        selected: "node-a",
        items: [OutboundInfo(tag: "node-a", urlTestDelay: 65535)],
      ),
    ];
    final healthy = [
      OutboundGroup(
        tag: "select",
        selected: "node-a",
        items: [OutboundInfo(tag: "node-a", urlTestDelay: 200)],
      ),
    ];

    test("rechecks a failed selected node with a cooldown and resets after recovery", () {
      final gate = FailedSelectedOutboundRetestGate();

      expect(gate.shouldRetest(failed, start), isTrue);
      expect(gate.shouldRetest(failed, start.add(const Duration(seconds: 5))), isFalse);
      expect(gate.shouldRetest(failed, start.add(const Duration(seconds: 31))), isTrue);
      expect(gate.shouldRetest(healthy, start.add(const Duration(seconds: 32))), isFalse);
      expect(gate.shouldRetest(failed, start.add(const Duration(seconds: 33))), isTrue);
    });

    test("does not retest an automatic group or an untested selected node", () {
      final gate = FailedSelectedOutboundRetestGate();

      expect(
        gate.shouldRetest([
          OutboundGroup(
            tag: "select",
            selected: "balance",
            items: [OutboundInfo(tag: "balance", isGroup: true, urlTestDelay: 65535)],
          ),
        ], start),
        isFalse,
      );
      expect(
        gate.shouldRetest([
          OutboundGroup(
            tag: "select",
            selected: "node-a",
            items: [OutboundInfo(tag: "node-a", urlTestDelay: 0)],
          ),
        ], start),
        isFalse,
      );
    });

    test("refreshes the latest group state after a quiet interval", () async {
      final events = await freshCoreActiveGroups(
        Stream.value(failed),
        refreshInterval: const Duration(milliseconds: 10),
      ).take(3).toList();

      expect(events.map((groups) => groups.isEmpty), [true, false, false]);
      expect(events[2].single.items.single.urlTestDelay, 65535);
    });
  });

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
