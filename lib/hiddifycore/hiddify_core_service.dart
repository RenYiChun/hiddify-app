import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:grpc/grpc.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/log/model/log_level.dart' as config_log_level;
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/core_interface/core_interface_wrapper_stub.dart'
    if (dart.library.io) 'package:hiddify/hiddifycore/core_interface/core_interface_wrapper.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcommon/common.pb.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore_service.pbgrpc.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/singbox/model/core_status.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/singbox/model/warp_account.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loggy/loggy.dart' as loggyl;
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

@visibleForTesting
bool isRecoverableRestartGrpcDisconnect(GrpcError error) {
  if (error.code != StatusCode.unknown) return false;
  final message = error.message ?? "";
  return message.contains("HTTP/2 error") && message.contains("Connection is being forcefully terminated");
}

typedef RuntimeOptionWarningLogger = void Function(String message);

@visibleForTesting
SingboxConfigOption normalizeCoreRuntimeOptions(SingboxConfigOption options, {RuntimeOptionWarningLogger? logWarning}) {
  var runtimeOptions = options;

  if (runtimeOptions.ipv6Mode == IPv6Mode.disable && runtimeOptions.directDnsDomainStrategy == DomainStrategy.auto) {
    logWarning?.call("using IPv4-only direct DNS strategy because IPv6 mode is disabled");
    runtimeOptions = runtimeOptions.copyWith(directDnsDomainStrategy: DomainStrategy.ipv4Only);
  }
  if (runtimeOptions.ipv6Mode == IPv6Mode.disable && runtimeOptions.remoteDnsDomainStrategy == DomainStrategy.auto) {
    logWarning?.call("using IPv4-only remote DNS strategy because IPv6 mode is disabled");
    runtimeOptions = runtimeOptions.copyWith(remoteDnsDomainStrategy: DomainStrategy.ipv4Only);
  }

  return runtimeOptions;
}

@visibleForTesting
String summarizeConfigEntriesForDiagnostics(dynamic entries, List<String> keys) {
  if (entries is! List) return "[]";
  final summary = entries
      .whereType<Map>()
      .map((entry) {
        final normalized = entry.map((key, value) => MapEntry("$key", value));
        return summarizeConfigMapForDiagnostics(normalized, keys);
      })
      .where((entry) => entry.isNotEmpty);
  return summary.isEmpty ? "[]" : summary.join("; ");
}

@visibleForTesting
String summarizeConfigMapForDiagnostics(dynamic value, List<String> keys) {
  if (value is! Map) return "{}";
  final normalized = value.map((key, mapValue) => MapEntry("$key", mapValue));
  return keys
      .where((key) => normalized.containsKey(key) && normalized[key] != null)
      .map((key) => "$key=${formatConfigValueForDiagnostics(normalized[key])}")
      .join(", ");
}

@visibleForTesting
String summarizeProxyGroupOutboundsForDiagnostics(dynamic entries) {
  if (entries is! List) return "[]";
  final groupTags = {"select", "lowest", "balance", "process-stable-proxy §hide§"};
  final summary = entries.whereType<Map>().where((entry) => groupTags.contains("${entry["tag"]}")).map((entry) {
    final normalized = entry.map((key, value) => MapEntry("$key", value));
    return summarizeConfigMapForDiagnostics(normalized, [
      "tag",
      "type",
      "default",
      "strategy",
      "outbounds",
      "tolerance",
      "delay_acceptable_ratio",
      "interrupt_exist_connections",
    ]);
  });
  return summary.isEmpty ? "[]" : summary.join("; ");
}

@visibleForTesting
String formatConfigValueForDiagnostics(dynamic value) {
  if (value is List) {
    const limit = 8;
    final shown = value.take(limit).join(",");
    final suffix = value.length > limit ? ",... len=${value.length}" : "";
    return "[$shown$suffix]";
  }
  if (value is Map) return jsonEncode(value);
  return "$value";
}

class HiddifyCoreService with InfraLogger {
  HiddifyCoreService(this.ref);
  final Ref ref;

  // CoreHiddifyCoreService() {}
  final core = getCoreInterface();

  CoreStatus currentState = const CoreStatus.stopped();
  final statusController = BehaviorSubject<CoreStatus>();
  bool _stopInProgress = false;
  bool get isStopInProgress => _stopInProgress;
  final logController = BehaviorSubject<List<LogMessage>>.seeded(const <LogMessage>[]);
  final CallOptions? grpcOptions = null; //CallOptions(timeout: const Duration(milliseconds: 10000));
  final Map<String, StreamSubscription?> subscriptions = {};
  List<OutboundGroup> latest = [];
  String? _lastActiveGroupDiagnostics;

  Future<void> _triggerActiveUrlTest(String phase) async {
    try {
      final res = await core.bgClient.urlTest(
        UrlTestRequest(tag: ""),
        options: CallOptions(timeout: const Duration(seconds: 2)),
      );
      if (res.code != ResponseCode.OK) {
        loggy.warning("active url test [$phase] failed: ${res.code} ${res.message}");
      } else {
        loggy.info("active url test [$phase] queued");
      }
    } catch (error, stackTrace) {
      loggy.warning("active url test [$phase] could not be queued", error, stackTrace);
    }
  }

  void _logConfigOptionDiagnostics(SingboxConfigOption options) {
    loggy.info(
      "core options: "
      "enableTun=${options.enableTun}, "
      "setSystemProxy=${options.setSystemProxy}, "
      "ipv6Mode=${options.ipv6Mode}, "
      "directDns=${options.directDnsAddress}, "
      "directDnsStrategy=${options.directDnsDomainStrategy}, "
      "remoteDns=${options.remoteDnsAddress}, "
      "remoteDnsStrategy=${options.remoteDnsDomainStrategy}, "
      "strictRoute=${options.strictRoute}, "
      "tun=${options.tunImplementation}, "
      "mtu=${options.mtu}, "
      "bypassLan=${options.bypassLan}, "
      "allowLan=${options.allowConnectionFromLan}, "
      "directRouteConnectionLimit=${options.directRouteConnectionLimit}, "
      "proxyRouteConnectionLimit=${options.proxyRouteConnectionLimit}, "
      "processDirectRules=${options.enableProcessDirectRules}, "
      "processDirectNames=${formatConfigValueForDiagnostics(options.processDirectRuleNames)}, "
      "processStableProxyRules=${options.enableProcessStableProxyRules}, "
      "processStableProxyNames=${formatConfigValueForDiagnostics(options.processStableProxyRuleNames)}, "
      "processStableProxyExcludedKeywords=${formatConfigValueForDiagnostics(options.processStableProxyExcludedOutboundKeywords)}, "
      "dynamicDirectBypass=${options.enableDynamicDirectBypass}, "
      "dynamicDirectBypassMode=all-direct, "
      "dynamicDirectBypassTtl=${options.dynamicDirectBypassTtl.inSeconds}s, "
      "dynamicDirectBypassMaxRoutes=${options.dynamicDirectBypassMaxRoutes}, "
      "dynamicDirectBypassMaxRoutesPerHost=${options.dynamicDirectBypassMaxRoutesPerHost}, "
      "fakeDns=${options.enableFakeDns}, "
      "independentDnsCache=${options.independentDnsCache}",
    );
  }

  Future<void> _logGeneratedConfigDiagnostics(String phase) async {
    try {
      final directories = ref.read(appDirectoriesProvider).requireValue;
      final configFile = File(
        "${directories.workingDir.path}${Platform.pathSeparator}data${Platform.pathSeparator}current-config.json",
      );
      if (!await configFile.exists()) {
        loggy.debug("core generated config [$phase]: missing at ${configFile.path}");
        return;
      }

      final decoded = jsonDecode(await configFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        loggy.warning("core generated config [$phase]: unexpected json shape");
        return;
      }

      final dns = decoded["dns"];
      final route = decoded["route"];
      loggy.info(
        "core generated config [$phase] dns: "
        "${summarizeConfigMapForDiagnostics(dns, ["strategy", "final", "disable_expire", "independent_cache"])}",
      );
      loggy.info(
        "core generated config [$phase] inbounds: "
        "${summarizeConfigEntriesForDiagnostics(decoded["inbounds"], ["tag", "type", "address", "stack", "mtu", "auto_route", "strict_route", "route_exclude_address", "listen", "listen_port", "set_system_proxy"])}",
      );
      loggy.info(
        "core generated config [$phase] dns servers: "
        "${summarizeConfigEntriesForDiagnostics(dns is Map ? dns["servers"] : null, ["tag", "type", "server", "server_port", "detour", "domain_resolver", "connect_timeout", "servers", "parallel"])}",
      );
      loggy.info(
        "core generated config [$phase] dns rules: "
        "${summarizeConfigEntriesForDiagnostics(dns is Map ? dns["rules"] : null, ["server", "domain", "domain_suffix", "rule_set", "strategy", "rewrite_ttl"])}",
      );
      loggy.info(
        "core generated config [$phase] route: "
        "${summarizeConfigMapForDiagnostics(route, ["final", "auto_detect_interface", "default_domain_resolver", "rule_set"])}",
      );
      loggy.info(
        "core generated config [$phase] custom: "
        "${summarizeConfigMapForDiagnostics(decoded["custom"], ["hiddify-route-direct-connection-limit", "hiddify-route-proxy-connection-limit", "hiddify-process-stable-proxy-enabled", "hiddify-process-stable-proxy-rule-names", "hiddify-process-stable-proxy-excluded-keywords", "hiddify-process-stable-proxy-candidate-outbounds", "hiddify-process-stable-proxy-excluded-outbounds", "hiddify-dynamic-direct-bypass-enabled", "hiddify-dynamic-direct-bypass-ttl", "hiddify-dynamic-direct-bypass-max-routes", "hiddify-dynamic-direct-bypass-max-routes-per-host"])}",
      );
      loggy.info(
        "core generated config [$phase] proxy groups: "
        "${summarizeProxyGroupOutboundsForDiagnostics(decoded["outbounds"])}",
      );
    } catch (error, stackTrace) {
      loggy.warning("core generated config [$phase]: failed to read diagnostics", error, stackTrace);
    }
  }

  void _logActiveGroupDiagnostics(List<OutboundGroup> groups) {
    final summary = groups
        .map((group) {
          final selectedItem = group.items.where((item) => item.tag == group.selected).firstOrNull;
          final selectedDetail = selectedItem == null
              ? ""
              : ", selectedType=${selectedItem.type}, delay=${selectedItem.urlTestDelay}, real=${selectedItem.groupSelectedTag}";
          return "tag=${group.tag}, type=${group.type}, selected=${group.selected}, items=${group.items.length}$selectedDetail";
        })
        .join("; ");
    if (summary == _lastActiveGroupDiagnostics) return;
    _lastActiveGroupDiagnostics = summary;
    loggy.info("active proxy groups: ${summary.isEmpty ? "[]" : summary}");
  }

  Future<void> init() async {
    await setup()
        .mapLeft((e) {
          loggy.error(e);
          if (PlatformUtils.isIOS) return;
          statusController.add(const CoreStatus.stopped());
          ref.read(inAppNotificationControllerProvider).showErrorToast(e);
        })
        .map((_) {
          loggy.info("Hiddify-core setup done");
          ref.read(coreRestartSignalProvider.notifier).restart();
        })
        .run();
  }

  /// validates config by path and save it
  ///
  /// [path] is used to save validated config
  /// [tempPath] includes base config, possibly invalid
  /// [debug] indicates if debug mode (avoid in prod)

  TaskEither<String, Unit> validateConfigByPath(String path, String tempPath, bool debug) {
    return TaskEither(() async {
      try {
        final response = await core.fgClient.parse(ParseRequest(tempPath: tempPath, configPath: path, debug: false));
        if (response.responseCode != ResponseCode.OK) return left("${response.responseCode} ${response.message}");
      } catch (e) {
        await setup().run();
        final response = await core.fgClient.parse(ParseRequest(tempPath: tempPath, configPath: path, debug: false));
        if (response.responseCode != ResponseCode.OK) return left("${response.responseCode} ${response.message}");
      }
      return right(unit);
    });
  }

  TaskEither<String, String> generateFullConfigByPath(String path) {
    return TaskEither(() async {
      final response = await core.fgClient.parse(ParseRequest(configPath: path, debug: false));
      if (response.responseCode != ResponseCode.OK) return left("${response.responseCode} ${response.message}");
      return right(response.content);
    });
  }

  TaskEither<String, Unit> setup() {
    return TaskEither(() async {
      try {
        final directories = ref.read(appDirectoriesProvider).requireValue;
        final debug = ref.read(debugModeNotifierProvider);
        final setupResponse = await core.setup(directories, debug, 3);

        if (setupResponse.isNotEmpty) {
          return left(setupResponse);
        }

        await startListeningLogs("fg", core.fgClient);
        // await startListeningStatus("fg", core.fgClient);
        if (!core.isSingleChannel()) {
          await startListeningLogs("bg", core.bgClient);
        }
        statusController.add(currentState);
        await startListeningStatus("bg", core.bgClient);
        // ref.read(coreRestartSignalProvider.notifier).restart();
        return right(unit);
      } catch (e) {
        return left(e.toString());
      }
    });
  }

  TaskEither<String, Unit> changeOptions(SingboxConfigOption options) {
    return TaskEither(() async {
      final runtimeOptions = normalizeCoreRuntimeOptions(options, logWarning: loggy.warning);
      final settingsJson = jsonEncode(runtimeOptions.toJson());
      loggy.debug("changing options");
      _logConfigOptionDiagnostics(runtimeOptions);
      // latestOptions = options;
      try {
        final res = await core.fgClient.changeHiddifySettings(
          ChangeHiddifySettingsRequest(hiddifySettingsJson: settingsJson),
        );
        if (res.messageType != MessageType.EMPTY) return left("${res.messageType} ${res.message}");
        await core.bgClient.changeHiddifySettings(ChangeHiddifySettingsRequest(hiddifySettingsJson: settingsJson));
      } on GrpcError catch (e) {
        if (e.code == StatusCode.unavailable) {
          loggy.debug("background core is not started yet! $e");
        } else {
          rethrow;
        }
      }

      return right(unit);
    });
  }

  TaskEither<ConnectionFailure, Unit> start(String path, String name, bool disableMemoryLimit) {
    return TaskEither(() async {
      _stopInProgress = false;
      statusController.add(currentState = const CoreStatus.starting());
      loggy.debug("starting");
      final background = await core.setupBackground(path, name);
      if (background != const CoreStatus.started()) {
        statusController.add(currentState = const CoreStatus.stopped());
        return left(background.getCoreAlert() ?? const ConnectionFailure.unexpected("failed to start core"));
      }
      if (!core.isSingleChannel()) {
        await startListeningLogs("bg", core.bgClient);
        await startListeningStatus("bg", core.bgClient);
      }
      // if (latestOptions != null) {
      //   await core.bgClient.changeHiddifySettings(
      //     ChangeHiddifySettingsRequest(
      //       hiddifySettingsJson: jsonEncode(latestOptions!.toJson()),
      //     ),
      //   );
      // }
      // final content = await File(path).readAsString();
      // loggy.debug("starting with content: $content");
      try {
        final res = await core.bgClient.start(
          StartRequest(
            configPath: path,
            configName: name,
            // configContent: content,
            disableMemoryLimit: disableMemoryLimit,
          ),
        );
        ref.read(coreRestartSignalProvider.notifier).restart();
        await _logGeneratedConfigDiagnostics("start response ${res.messageType.name}");
        if (res.messageType != MessageType.ALREADY_STARTED && res.messageType != MessageType.EMPTY) {
          final alert = res.message.contains("denied") ? CoreAlert.requestVPNPermission : CoreAlert.startFailed;
          currentState = CoreStatus.stopped(
            alert: alert,
            message: "failed to start core ${res.messageType} ${res.message}",
          );

          statusController.add(currentState);

          return left(
            currentState.getCoreAlert() ??
                ConnectionFailure.unexpected("failed to start core ${res.messageType} ${res.message}"),
          );
        }
        await _triggerActiveUrlTest("start");
      } on GrpcError catch (e) {
        loggy.error("failed to start bg core: $e");
        await _logGeneratedConfigDiagnostics("start grpc error");
        ref.read(coreRestartSignalProvider.notifier).restart();
        if (e.code == StatusCode.unavailable) {
          return left(const ConnectionFailure.unexpected("background core is not started yet!"));
        }
        // throw InvalidConfig(e.message);
        // throw DioException.connectionError(requestOptions: RequestOptions(), reason: e.codeName, error: e);

        // throw DioException(requestOptions: RequestOptions(), error: e);
        return left(const ConnectionFailure.unexpected("failed to start background core"));
      }

      // if (res.messageType != MessageType.EMPTY) return left(res);

      return right(unit);
    });
  }

  TaskEither<String, Unit> stop() {
    return TaskEither(() async {
      loggy.debug("stopping");
      _stopInProgress = true;
      statusController.add(currentState = const CoreStatus.stopping());
      var errMsg = "";
      try {
        await core.bgClient.stop(Empty());
      } on GrpcError catch (e) {
        if (e.code == StatusCode.unknown && !(e.message?.contains("HTTP/2") ?? false)) {
          errMsg = e.message ?? "failed to stop core: $e";

          loggy.error("failed to stop bg core: $e");
        }
      } catch (e) {
        loggy.error("failed to stop bg core: $e");
        // left("failed to stop core: $e");
      }
      if (!await core.stop()) {}
      _stopInProgress = false;
      statusController.add(currentState = const CoreStatus.stopped());
      if (errMsg.isNotEmpty) return left(errMsg);
      return right(unit);
    });
  }

  TaskEither<String, Unit> restart(String path, String name, bool disableMemoryLimit) {
    return TaskEither(() async {
      loggy.debug("restarting");
      _stopInProgress = false;
      // if (!await core.restart(path, name)) {
      try {
        final res = await core.bgClient.restart(
          StartRequest(configPath: path, configName: name, disableMemoryLimit: disableMemoryLimit, delayStart: true),
        );
        await _logGeneratedConfigDiagnostics("restart response ${res.messageType.name}");
        if (res.messageType != MessageType.EMPTY) return left("${res.messageType} ${res.message}");
        await _triggerActiveUrlTest("restart");
      } on GrpcError catch (e) {
        loggy.error("failed to restart bg core: $e");
        await _logGeneratedConfigDiagnostics("restart grpc error");
        if (isRecoverableRestartGrpcDisconnect(e)) {
          loggy.warning("restart bg core transport closed; falling back to full stop/start");
          return _restartByStopStart(path, name, disableMemoryLimit).run();
        }
        if (e.code == StatusCode.unknown && !(e.message?.contains("HTTP/2 error") ?? false)) {
          return left("${e.message}");
        }
      }

      return right(unit);
      // await stop().run();
      // return await start(path, name, disableMemoryLimit).run();
      // }
      // if (!core.isSingleChannel()) {
      //   await startListeningStatus("bg", core.bgClient);
      //   await startListeningLogs("bg", core.bgClient);
      // }
      // return right(unit);
    });
  }

  TaskEither<String, Unit> _restartByStopStart(String path, String name, bool disableMemoryLimit) {
    return stop().flatMap((_) => start(path, name, disableMemoryLimit).mapLeft((failure) => "$failure"));
  }

  TaskEither<String, Unit> resetTunnel() {
    return TaskEither(() async {
      // only available on iOS (and macOS later)
      if (!PlatformUtils.isIOS) {
        throw UnimplementedError("reset tunnel function unavailable on platform");
      }

      // loggy.debug("resetting tunnel");
      final res = await core.resetTunnel();
      if (res) {
        return right(unit);
      }
      return left("failed to reset tunnel");
    });
  }

  // Stream<List<OutboundGroup>> watchGroups() async* {
  //   loggy.debug("watching groups");
  //   yield* core.bgClient.outboundsInfo(Empty()).map((event) => event.items);
  //   // res?.cancel();
  // }

  Stream<OutboundGroup?> watchGroup() async* {
    loggy.debug("watching group");
    // interrupt managed by core

    if (!core.isInitialized()) {
      loggy.debug("core is not initialized, returning empty group stream");
      return;
    }
    try {
      yield* core.bgClient.outboundsInfo(Empty()).map((event) => event.items.isEmpty ? null : event.items.first);
    } catch (e) {
      loggy.error("error watching group: $e");
      rethrow;
    }
    // //emitting first event immediately
    // yield* core.bgClient.outboundsInfo(Empty()).take(1).map((event) => event.items.isEmpty ? null : event.items.first);
    // //emitting other event after every 4 seconds(latest event)
    // yield* core.bgClient.outboundsInfo(Empty()).throttleTime(const Duration(seconds: 4), leading: false, trailing: true).map((event) => event.items.isEmpty ? null : event.items.first);
  }

  Stream<List<OutboundGroup>> watchActiveGroups() async* {
    loggy.info("watching active groups");

    if (!core.isInitialized()) {
      loggy.debug("core is not initialized, returning empty group stream");
      return;
    }

    try {
      yield* core.bgClient
          .mainOutboundsInfo(Empty())
          .map((event) {
            latest = event.items;
            _logActiveGroupDiagnostics(latest);
            return latest;
          })
          .startWith(latest);
    } catch (e) {
      loggy.error("error watching active groups: $e");
      rethrow;
    }
  }

  //
  // Stream<SingboxStatus> watchStatus() => _status;

  ResponseStream<SystemInfo> watchStats() {
    loggy.debug("watching stats");
    try {
      return core.bgClient.getSystemInfoStream(Empty());
    } catch (e) {
      loggy.error("error watching stats: $e");
      rethrow;
    }
  }

  TaskEither<String, Unit> selectOutbound(String groupTag, String outboundTag) {
    return TaskEither(() async {
      loggy.debug("selecting outbound");
      try {
        final res = await core.bgClient.selectOutbound(
          SelectOutboundRequest(groupTag: groupTag, outboundTag: outboundTag),
          options: CallOptions(timeout: const Duration(seconds: 1)),
        );
        if (res.code != ResponseCode.OK) return left("${res.code} ${res.message}");

        return right(unit);
      } catch (e) {
        loggy.error("error selecting outbound: $e");
        rethrow;
      }
    });
  }

  TaskEither<String, Unit> urlTest(String tag) {
    return TaskEither(() async {
      loggy.debug("url test");
      try {
        final res = await core.bgClient.urlTest(UrlTestRequest(tag: tag));
        if (res.code != ResponseCode.OK) return left("${res.code} ${res.message}");

        return right(unit);
      } catch (e) {
        loggy.error("error in url test: $e");
        rethrow;
      }
    });
  }

  List<LogMessage> logBuffer = [];

  // SingboxConfigOption? latestOptions;

  Stream<List<LogMessage>> watchLogs(String path) async* {
    yield List<LogMessage>.unmodifiable(logBuffer);
    if (!core.isInitialized()) {
      loggy.debug("core is not initialized, returning empty log stream");
      return;
    }
    await startListeningLogs("bg", core.bgClient);
    await startListeningLogs("fg", core.fgClient);
    try {
      yield* logController.stream;
    } catch (e) {
      loggy.error("error watching logs: $e");
      rethrow;
    }
    // Stream<List<String>> logStream(CoreClient coreClient) {
    //   return coreClient.logListener(Empty()).asBroadcastStream().map((event) => [event.message]).onErrorResume((error, stackTrace) {
    //     loggy.debug('Error in $coreClient: $error, retrying...');
    //     final delay = (currentState == const SingboxStatus.stopped()) ? 5 : 1;
    //     return const Stream<List<String>>.empty().delay(Duration(seconds: delay)).concatWith([logStream(coreClient)]);
    //   });
    // }

    // // Create streams for both fg and bg clients with retry logic
    // final fgLogStream = logStream(core.fgClient);

    // if (core.bgClient == core.fgClient) {
    //   yield* fgLogStream;
    //   return;
    // }
    // final bgLogStream = logStream(core.bgClient);
    // yield* MergeStream([bgLogStream, fgLogStream]);
  }

  TaskEither<String, Unit> clearLogs() {
    return TaskEither(() async {
      loggy.debug("clearing logs");
      logBuffer.clear();
      logController.add(const <LogMessage>[]);
      // final res = await core.bgClient(Empty());
      // if (res.code != ResponseCode.OK) return left("${res.code} ${res.message}");
      return right(unit);
    });
  }

  TaskEither<String, WarpResponse> generateWarpConfig({
    required String licenseKey,
    required String previousAccountId,
    required String previousAccessToken,
  }) {
    return TaskEither(() async {
      loggy.debug("generating warp config");
      final warpConfig = await core.fgClient.generateWarpConfig(
        GenerateWarpConfigRequest(
          licenseKey: licenseKey,
          accountId: previousAccountId,
          accessToken: previousAccessToken,
        ),
      );
      // if (warpConfig.code != ResponseCode.OK) return left("${warpConfig.code} ${warpConfig.message}");
      final WarpResponse warp = (
        log: warpConfig.log,
        accountId: warpConfig.account.accountId,
        accessToken: warpConfig.account.accessToken,
        wireguardConfig: jsonEncode(warpConfig.config.toProto3Json()),
      );
      return right(warp);
    });
  }

  Stream<CoreStatus> watchStatus() async* {
    await startListeningStatus("bg", core.bgClient);
    yield* statusController.stream;
    // .endWith(const CoreStatus.stopped());
  }

  Future<void> startListeningStatus(String key, CoreClient cc) async {
    await listenSingle<CoreStatus>(
      "${key}StatusListener",
      () =>
          coreStatusListenerStream(
            cc
                .coreInfoListener(Empty(), options: grpcOptions)
                .doOnCancel(() {
                  loggy.debug("status listener [$key] canceled");
                })
                .doOnData((event) {
                  loggy.debug("status", event);
                })
                .doOnDone(() {
                  loggy.debug("status listener [$key] done");
                }),
          ).doOnData((event) {
            if (_stopInProgress && event is CoreStarted) {
              loggy.debug("ignoring started status while stop is in progress");
              return;
            }
            if (event is CoreStopped) {
              _stopInProgress = false;
            }
            currentState = event;
            statusController.add(currentState);
          }),
      // .endWith(const CoreStatus.stopped())
      onError: (error) {
        loggy.error("Stream error in ${key}StatusListener: $error");

        // currentState = const CoreStatus.stopped();
        // statusController.add(currentState);

        // startListeningStatus(key, cc);
      },
    );
  }

  Future<void> startListeningLogs(String key, CoreClient cc) async {
    final logLevel = ref.read(ConfigOptions.logLevel);
    final coreLogLevel = getCoreLogLevel(logLevel);
    final listenKey = "${key}LogListener";
    // await stopListenSingle(listenKey);
    await listenSingle<LogMessage>(listenKey, () {
      return cc.logListener(LogRequest(level: coreLogLevel), options: grpcOptions).map((event) {
        // Handle incoming event
        logBuffer.add(event);
        if (logBuffer.length > 300) {
          logBuffer.removeAt(0);
        }
        logController.add(logBuffer);
        // loggy.log(getLogLevel(event.level), event.message);
        event.message.split('\n').forEach((line) {
          loggy.log(getLogLevel(event.level), line);
        });
        return event;
      });
    });
  }

  Future<void> stopListenSingle(String key) async {
    // Collect keys to remove first
    final keysToRemove = subscriptions.entries
        .where((entry) => entry.key.startsWith(key))
        .map((entry) => entry.key)
        .toList();

    // Cancel and remove
    for (final k in keysToRemove) {
      final sub = subscriptions[k];
      await sub?.cancel(); // cancel the subscription

      subscriptions.remove(k);
    }
  }

  Future<StreamSubscription<T>?> listenSingle<T>(
    String key,
    Stream<T> Function() stream, {
    Function(dynamic error)? onError,
  }) async {
    if (subscriptions.containsKey(key)) {
      // return subscriptions[key] as StreamSubscription<T>?;
      await stopListenSingle(key);
    }
    subscriptions[key] = null;
    subscriptions[key] = stream().listen(
      (event) {
        // loggy.debug(event);
      },
      cancelOnError: true,
      onError: (error) {
        loggy.log(loggyl.LogLevel.error, 'Stream error: $error');
        onError?.call(error);
        subscriptions[key]?.cancel();
        subscriptions.remove(key);
      },
    );
    return subscriptions[key] as StreamSubscription<T>?;
  }

  loggyl.LogLevel getLogLevel(LogLevel level) {
    return switch (level) {
      LogLevel.DEBUG => loggyl.LogLevel.debug,
      LogLevel.INFO => loggyl.LogLevel.info,
      LogLevel.WARNING => loggyl.LogLevel.warning,
      LogLevel.ERROR => loggyl.LogLevel.error,
      LogLevel.FATAL => loggyl.LogLevel.error,
      _ => loggyl.LogLevel.info, // Default case
    };
  }

  LogLevel getCoreLogLevel(config_log_level.LogLevel level) {
    return switch (level) {
      config_log_level.LogLevel.trace => LogLevel.TRACE,
      config_log_level.LogLevel.debug => LogLevel.DEBUG,
      config_log_level.LogLevel.info => LogLevel.INFO,
      config_log_level.LogLevel.warn => LogLevel.WARNING,
      config_log_level.LogLevel.error => LogLevel.ERROR,
      config_log_level.LogLevel.fatal => LogLevel.FATAL,
      config_log_level.LogLevel.panic => LogLevel.FATAL,
    };
  }

  Future<void> closeFront() async {
    if (!core.isInitialized()) {
      return;
    }
    if (!core.isSingleChannel()) {
      await stopListenSingle("fg");
      await stopListenSingle("bg");
      try {
        await core.fgClient.close(CloseRequest(mode: SetupMode.GRPC_NORMAL_INSECURE));
      } catch (e) {
        // The foreground channel may already be closed during shutdown.
      }
      try {
        await core.fgClient.close(CloseRequest(mode: SetupMode.GRPC_NORMAL));
      } catch (e) {
        // Retry the alternate close mode without failing app shutdown.
      }
    }
  }
}

Stream<CoreStatus> coreStatusListenerStream(Stream<CoreInfoResponse> events) {
  return events.map(CoreStatus.fromCoreInfo);
}
