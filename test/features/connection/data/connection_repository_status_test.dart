import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/singbox/model/core_status.dart';

void main() {
  group("connectionStatusFromCore", () {
    test("keeps started core in connecting state until an active proxy has a valid delay", () {
      expect(connectionStatusFromCore(const CoreStatus.started(), activeGroups: []), const Connecting());

      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
          ],
        ),
        const Connecting(),
      );

      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 65535)]),
          ],
        ),
        const Connecting(),
      );
    });

    test("marks started core connected only after the selected leaf has a valid delay", () {
      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
            _group("balance", selected: "node-a", items: [_info("node-a", delay: 167)]),
          ],
        ),
        const Connected(),
      );
    });

    test("preserves non-started core states", () {
      expect(connectionStatusFromCore(const CoreStatus.starting()), const Connecting());
      expect(connectionStatusFromCore(const CoreStatus.stopping()), const Disconnecting());
      expect(connectionStatusFromCore(const CoreStatus.stopped()), const Disconnected());
    });
  });

  group("connectionStatusUpdatesFromCore", () {
    test("does not emit a transient connecting state for an already-started core", () async {
      final statuses = await connectionStatusUpdatesFromCore(
        Stream.value(const CoreStatus.started()),
        () => Stream.value([
          _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
          _group("balance", selected: "node-a", items: [_info("node-a", delay: 176)]),
        ]),
      ).toList();

      expect(statuses, [const Connected()]);
    });

    test("suppresses duplicate connected emissions when started status is replayed", () async {
      final statuses = await connectionStatusUpdatesFromCore(
        Stream.fromIterable([const CoreStatus.started(), const CoreStatus.started()]),
        () => Stream.value([
          _group("select", selected: "node-a", items: [_info("node-a", delay: 176)]),
        ]),
      ).toList();

      expect(statuses, [const Connected()]);
    });
  });
}

OutboundGroup _group(String tag, {required String selected, required List<OutboundInfo> items}) {
  return OutboundGroup(tag: tag, selected: selected, items: items);
}

OutboundInfo _info(String tag, {bool isGroup = false, required int delay}) {
  return OutboundInfo(tag: tag, isGroup: isGroup, urlTestDelay: delay);
}
