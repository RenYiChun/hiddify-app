import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/singbox/model/core_status.dart';

void main() {
  group("connectionStatusFromCore", () {
    test("keeps core starting as connecting", () {
      expect(connectionStatusFromCore(const CoreStatus.starting()), const Connecting());
    });

    test("marks started core as checking when no test result exists yet", () {
      expect(connectionStatusFromCore(const CoreStatus.started(), activeGroups: []), const Checking());

      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
          ],
        ),
        const Checking(),
      );
    });

    test("marks started core unavailable when all observed leaf tests failed", () {
      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
            _group("balance", selected: "node-a", items: [_info("node-a", delay: 65535)]),
            _group("lowest", selected: "node-b", items: [_info("node-b", delay: 65535)]),
          ],
        ),
        const OutboundUnavailable(),
      );
    });

    test("marks started core connected when current selected leaf has a valid delay", () {
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

    test("marks balance or lowest mode connected when any observed leaf can connect", () {
      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
            _group("balance", selected: "node-a", items: [_info("node-a", delay: 65535)]),
            _group("lowest", selected: "node-b", items: [_info("node-b", delay: 167)]),
          ],
        ),
        const Connected(),
      );
    });

    test("marks concrete node selection unavailable when selected leaf fails and another leaf can connect", () {
      expect(
        connectionStatusFromCore(
          const CoreStatus.started(),
          activeGroups: [
            _group("select", selected: "node-a", items: [_info("node-a", delay: 65535), _info("node-b", delay: 167)]),
          ],
        ),
        const CurrentOutboundUnavailable(),
      );
    });

    test(
      "marks concrete node selection checking when selected leaf is still unknown even if another leaf can connect",
      () {
        expect(
          connectionStatusFromCore(
            const CoreStatus.started(),
            activeGroups: [
              _group("select", selected: "node-a", items: [_info("node-a", delay: 0), _info("node-b", delay: 167)]),
            ],
          ),
          const Checking(),
        );
      },
    );

    test("preserves non-started core states", () {
      expect(connectionStatusFromCore(const CoreStatus.stopping()), const Disconnecting());
      expect(connectionStatusFromCore(const CoreStatus.stopped()), const Disconnected());
    });
  });

  group("connectionStatusUpdatesFromCore", () {
    test("marks already-started core checking until test evidence arrives", () async {
      final statuses = await connectionStatusUpdatesFromCore(
        Stream.value(const CoreStatus.started()),
        () => Stream.value([
          _group("select", selected: "balance", items: [_info("balance", isGroup: true, delay: 0)]),
          _group("balance", selected: "node-a", items: [_info("node-a", delay: 0)]),
        ]),
      ).toList();

      expect(statuses, [const Checking()]);
    });

    test("suppresses duplicate started status replays", () async {
      final statuses = await connectionStatusUpdatesFromCore(
        Stream.fromIterable([const CoreStatus.started(), const CoreStatus.started()]),
        () => Stream.value([
          _group("select", selected: "node-a", items: [_info("node-a", delay: 176)]),
        ]),
      ).toList();

      expect(statuses, [const Checking(), const Connected()]);
    });
  });
}

OutboundGroup _group(String tag, {required String selected, required List<OutboundInfo> items}) {
  return OutboundGroup(tag: tag, selected: selected, items: items);
}

OutboundInfo _info(String tag, {bool isGroup = false, required int delay}) {
  return OutboundInfo(tag: tag, isGroup: isGroup, urlTestDelay: delay);
}
