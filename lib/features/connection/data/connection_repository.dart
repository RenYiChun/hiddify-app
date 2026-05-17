import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
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
  });

  final Ref ref;

  final Directories directories;
  final HiddifyCoreService singbox;

  final ConfigOptionRepository configOptionRepository;
  final ProfilePathResolver profilePathResolver;

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
  return statusEvents.switchMap((event) {
    if (event case CoreStarted()) {
      return watchActiveGroups()
          .map((groups) => connectionStatusFromCore(event, activeGroups: groups))
          .onErrorReturn(const Connecting());
    }
    return Stream.value(connectionStatusFromCore(event));
  }).distinct();
}

@visibleForTesting
ConnectionStatus connectionStatusFromCore(CoreStatus event, {List<OutboundGroup> activeGroups = const []}) {
  return switch (event) {
    CoreStopped() => Disconnected(event.getCoreAlert()),
    CoreStarting() => const Connecting(),
    CoreStarted() => _hasValidActiveProxy(activeGroups) ? const Connected() : const Connecting(),
    CoreStopping() => const Disconnecting(),
  };
}

bool _hasValidActiveProxy(List<OutboundGroup> groups) {
  if (groups.isEmpty) return false;

  final groupsByTag = <String, OutboundGroup>{
    for (final group in groups)
      if (group.tag.isNotEmpty) group.tag: group,
  };

  var group = groupsByTag["select"] ?? groups.first;
  final visited = <String>{};

  while (visited.add(group.tag)) {
    final selectedItem = _selectedItem(group);
    if (selectedItem == null) return false;

    if (_hasSuccessfulDelay(selectedItem)) return true;
    if (!selectedItem.isGroup) return false;

    final nestedGroup = groupsByTag[selectedItem.tag];
    if (nestedGroup == null) return false;
    group = nestedGroup;
  }

  return false;
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
  return !info.isGroup || info.groupSelectedTag.isNotEmpty;
}
