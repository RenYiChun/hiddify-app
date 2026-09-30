import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/proxy_availability.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  test('counts visible leaf nodes as test results change', () {
    final working = OutboundInfo(tag: 'working', isVisible: true, urlTestDelay: 201);
    final pending = OutboundInfo(tag: 'pending', isVisible: true);
    final failed = OutboundInfo(tag: 'failed', isVisible: true, urlTestDelay: 65535);
    final group = OutboundGroup(
      tag: 'select',
      items: [
        OutboundInfo(tag: 'lowest', isGroup: true, isVisible: true),
        working,
        pending,
        failed,
        OutboundInfo(tag: 'hidden', urlTestDelay: 180),
      ],
    );

    expect(countProxyAvailability(group).total, 3);
    expect(countProxyAvailability(group).available, 1);

    pending.urlTestDelay = 240;
    expect(countProxyAvailability(group).available, 2);

    working.urlTestDelay = 65535;
    expect(countProxyAvailability(group).available, 1);
  });
}
