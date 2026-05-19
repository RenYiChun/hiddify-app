import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/connection/data/windows_port_reservation_service.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/profile/data/profile_path_resolver.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/warp_option/warp_option_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/singbox/model/core_status.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

abstract interface class ConnectionRepository {
  SingboxConfigOption? get configOptionsSnapshot;

  TaskEither<ConnectionFailure, Unit> setup();
  Stream<ConnectionStatus> watchConnectionStatus();
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity activeProfile, bool disableMemoryLimit);
  TaskEither<ConnectionFailure, Unit> disconnect();
  TaskEither<ConnectionFailure, Unit> reconnect(ProfileEntity activeProfile, bool disableMemoryLimit);
}

class ConnectionRepositoryImpl with ExceptionHandler, InfraLogger implements ConnectionRepository {
  ConnectionRepositoryImpl({
    required this.ref,
    required this.directories,
    required this.singbox,
    required this.configOptionRepository,
    required this.profilePathResolver,
    required this.windowsPortReservationService,
  });

  final Ref ref;

  final Directories directories;
  final HiddifyCoreService singbox;

  final ConfigOptionRepository configOptionRepository;
  final ProfilePathResolver profilePathResolver;
  final WindowsPortReservationService windowsPortReservationService;

  SingboxConfigOption? _configOptionsSnapshot;
  @override
  SingboxConfigOption? get configOptionsSnapshot => _configOptionsSnapshot;

  bool _initialized = false;

  @override
  TaskEither<ConnectionFailure, Unit> setup() {
    if (_initialized) return TaskEither.of(unit);
    return exceptionHandler(() {
      loggy.debug("setting up singbox");

      return singbox
          .setup()
          .map((r) {
            _initialized = true;
            return r;
          })
          .mapLeft(UnexpectedConnectionFailure.new)
          .run();
    }, UnexpectedConnectionFailure.new);
  }

  @override
  Stream<ConnectionStatus> watchConnectionStatus() {
    return connectionStatusUpdatesFromCore(singbox.watchStatus(), singbox.watchActiveGroups);
  }

  @override
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity activeProfile, bool disableMemoryLimit) => setup().flatMap(
    (_) => applyConfigOption(activeProfile).flatMap(
      (_) => singbox.start(profilePathResolver.file(activeProfile.id).path, activeProfile.name, disableMemoryLimit),
      // .mapLeft(UnexpectedConnectionFailure.new),
    ),
  );

  @override
  TaskEither<ConnectionFailure, Unit> disconnect() => singbox.stop().mapLeft(UnexpectedConnectionFailure.new);

  @override
  TaskEither<ConnectionFailure, Unit> reconnect(ProfileEntity activeProfile, bool disableMemoryLimit) =>
      applyConfigOption(activeProfile).flatMap(
        (_) => singbox
            .restart(profilePathResolver.file(activeProfile.id).path, activeProfile.name, disableMemoryLimit)
            .mapLeft(UnexpectedConnectionFailure.new),
      );

  @visibleForTesting
  TaskEither<ConnectionFailure, Unit> applyConfigOption(ProfileEntity prof) =>
      TaskEither.fromEither(configOptionRepository.fullOptionsOverrided(prof.profileOverride))
          .mapLeft((l) => ConnectionFailure.invalidConfigOption(null, l))
          .flatMap(
            (overridedOptions) => TaskEither.tryCatch(() async {
              final runtimeOptions = _normalizeRuntimeOptions(overridedOptions);
              final isWarpLicenseAgreed = ref.read(warpLicenseNotifierProvider);
              final isWarpEnabled = runtimeOptions.warp.enable || runtimeOptions.warp2.enable;
              if (!isWarpLicenseAgreed && isWarpEnabled) {
                final isAgreed = await ref.read(dialogNotifierProvider.notifier).showWarpLicense();
                if (isAgreed == true) {
                  await ref.read(warpLicenseNotifierProvider.notifier).agree();
                  // return (await applyConfigOption(prof).run()).match((l) => throw l, (_) => unit);
                } else {
                  throw const MissingWarpLicense();
                }
              }
              if (runtimeOptions.enableTun) {
                final portsReserved = await windowsPortReservationService.ensureReserved();
                if (!portsReserved) {
                  loggy.warning("Windows Hiddify port reservations could not be verified before VPN start");
                }
              }
              _configOptionsSnapshot = runtimeOptions;
              await singbox.changeOptions(runtimeOptions).run();
              return unit;
            }, (err, st) => err is ConnectionFailure ? err : ConnectionFailure.unexpected(err, st)),
          );

  SingboxConfigOption _normalizeRuntimeOptions(SingboxConfigOption options) {
    var runtimeOptions = options;

    if (runtimeOptions.ipv6Mode == IPv6Mode.disable && runtimeOptions.directDnsDomainStrategy == DomainStrategy.auto) {
      loggy.warning("using IPv4-only direct DNS strategy because IPv6 mode is disabled");
      runtimeOptions = runtimeOptions.copyWith(directDnsDomainStrategy: DomainStrategy.ipv4Only);
    }

    return runtimeOptions;
  }
}

@visibleForTesting
Stream<ConnectionStatus> connectionStatusUpdatesFromCore(
  Stream<CoreStatus> statusEvents,
  Stream<List<OutboundGroup>> Function() watchActiveGroups,
) {
  return statusEvents.distinct().switchMap((event) {
    if (event case CoreStarted()) {
      return watchActiveGroups()
          .map((groups) => connectionStatusFromCore(event, activeGroups: groups))
          .onErrorReturn(const Checking());
    }
    return Stream.value(connectionStatusFromCore(event));
  }).distinct();
}

@visibleForTesting
ConnectionStatus connectionStatusFromCore(CoreStatus event, {List<OutboundGroup> activeGroups = const []}) {
  return switch (event) {
    CoreStopped() => Disconnected(event.getCoreAlert()),
    CoreStarting() => const Connecting(),
    CoreStarted() => _connectionStatusFromActiveGroups(activeGroups),
    CoreStopping() => const Disconnecting(),
  };
}

ConnectionStatus _connectionStatusFromActiveGroups(List<OutboundGroup> groups) {
  if (groups.isEmpty) return const Checking();

  final groupsByTag = <String, OutboundGroup>{
    for (final group in groups)
      if (group.tag.isNotEmpty) group.tag: group,
  };

  final rootGroup = groupsByTag["select"] ?? groups.first;
  final selectedRootItem = _selectedItem(rootGroup);
  final observedLeaves = _observedLeafItems(groups).toList();
  if (selectedRootItem == null || observedLeaves.isEmpty) return const Checking();

  final hasSuccessfulLeaf = observedLeaves.any(_hasSuccessfulDelay);
  if (_isAutoSelectionMode(selectedRootItem)) {
    if (hasSuccessfulLeaf) return const Connected();

    final hasFailedLeaf = observedLeaves.any(_hasFailedDelay);
    final hasUnknownLeaf = observedLeaves.any(_hasUnknownDelay);
    if (hasFailedLeaf && !hasUnknownLeaf) return const OutboundUnavailable();

    return const Checking();
  }

  final selectedLeaf = selectedRootItem.isGroup ? _selectedLeaf(selectedRootItem.tag, groupsByTag) : selectedRootItem;
  if (selectedLeaf == null || _hasUnknownDelay(selectedLeaf)) return const Checking();
  if (_hasSuccessfulDelay(selectedLeaf)) return const Connected();
  if (hasSuccessfulLeaf) return const CurrentOutboundUnavailable();
  if (_hasFailedDelay(selectedLeaf)) return const OutboundUnavailable();

  return const Checking();
}

bool _isAutoSelectionMode(OutboundInfo selectedRootItem) {
  return selectedRootItem.isGroup && (selectedRootItem.tag == "balance" || selectedRootItem.tag == "lowest");
}

OutboundInfo? _selectedLeaf(String groupTag, Map<String, OutboundGroup> groupsByTag) {
  var group = groupsByTag[groupTag];
  if (group == null) return null;
  final visited = <String>{};

  while (visited.add(group!.tag)) {
    final selectedItem = _selectedItem(group);
    if (selectedItem == null) return null;

    if (!selectedItem.isGroup) return selectedItem;

    final nestedGroup = groupsByTag[selectedItem.tag];
    if (nestedGroup == null) return null;
    group = nestedGroup;
  }

  return null;
}

Iterable<OutboundInfo> _observedLeafItems(List<OutboundGroup> groups) sync* {
  for (final group in groups) {
    for (final item in group.items) {
      if (!item.isGroup) yield item;
    }
  }
}

OutboundInfo? _selectedItem(OutboundGroup group) {
  if (group.items.isEmpty) return null;
  for (final item in group.items) {
    if (item.tag == group.selected || item.isSelected) {
      return item;
    }
  }
  return null;
}

bool _hasSuccessfulDelay(OutboundInfo info) {
  final delay = info.urlTestDelay;
  if (delay <= 0 || delay >= 65000) return false;
  return true;
}

bool _hasFailedDelay(OutboundInfo info) {
  return info.urlTestDelay >= 65000;
}

bool _hasUnknownDelay(OutboundInfo info) {
  return info.urlTestDelay <= 0;
}
