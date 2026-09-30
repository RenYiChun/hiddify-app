import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxyAvailability {
  const ProxyAvailability({required this.total, required this.available});

  final int total;
  final int available;
}

ProxyAvailability countProxyAvailability(OutboundGroup group) {
  final nodesByTag = <String, OutboundInfo>{};
  for (final node in group.items) {
    if (node.isGroup || !node.isVisible || node.tag.isEmpty) continue;
    nodesByTag[node.tag] = node;
  }
  return ProxyAvailability(
    total: nodesByTag.length,
    available: nodesByTag.values.where((node) => node.urlTestDelay > 0 && node.urlTestDelay < 65000).length,
  );
}

final proxyAvailabilityProvider = StreamProvider.autoDispose<ProxyAvailability?>((ref) {
  final running = ref.watch(serviceRunningProvider).valueOrNull ?? false;
  if (!running) return Stream.value(null);

  return ref
      .watch(proxyRepositoryProvider)
      .watchProxies()
      .map((result) {
        final group = result.getOrElse((_) => null);
        return group == null ? null : countProxyAvailability(group);
      })
      .distinct((previous, next) => previous?.total == next?.total && previous?.available == next?.available);
});
