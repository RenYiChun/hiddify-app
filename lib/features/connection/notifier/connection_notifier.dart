import 'dart:io';

import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'connection_notifier.g.dart';

/// The core may become usable even when the restart RPC has not returned yet.
final reconnectProgressProvider = StateProvider<ReconnectProgress>((ref) => const ReconnectProgress());

class ReconnectProgress {
  const ReconnectProgress({this.pending = 0, this.sawCoreTransition = false, this.coreRecovered = false});

  final int pending;
  final bool sawCoreTransition;
  final bool coreRecovered;

  bool get isReconnecting => pending > 0 && !coreRecovered;

  ReconnectProgress start() => ReconnectProgress(pending: pending + 1);

  ReconnectProgress observe(ConnectionStatus status) {
    if (pending == 0) return this;
    if (status is Connecting || status is Disconnecting || status is Disconnected) {
      return ReconnectProgress(pending: pending, sawCoreTransition: true);
    }
    if (status is Connected && sawCoreTransition) {
      return ReconnectProgress(pending: pending, sawCoreTransition: true, coreRecovered: true);
    }
    return this;
  }

  ReconnectProgress finish() => pending <= 1
      ? const ReconnectProgress()
      : ReconnectProgress(pending: pending - 1, sawCoreTransition: sawCoreTransition, coreRecovered: coreRecovered);
}

@Riverpod(keepAlive: true)
class ConnectionNotifier extends _$ConnectionNotifier with AppLogger {
  @override
  Stream<ConnectionStatus> build() async* {
    if (Platform.isIOS) {
      await _connectionRepo.setup().mapLeft((l) {
        loggy.error("error setting up connection repository", l);
      }).run();
    }

    listenSelf((previous, next) async {
      if (previous == next) return;
      if (previous case AsyncData(:final value) when !value.isConnected) {
        if (next case AsyncData(value: final Connected _)) {
          await ref.read(hapticServiceProvider.notifier).heavyImpact();

          if (Platform.isAndroid && !ref.read(Preferences.storeReviewedByUser)) {
            if (await InAppReview.instance.isAvailable()) {
              InAppReview.instance.requestReview();
              ref.read(Preferences.storeReviewedByUser.notifier).update(true);
            }
          }
        }
      }
    });

    ref.listen(activeProfileProvider.select((value) => value.asData?.value), (previous, next) async {
      if (previous == null) return;
      final shouldReconnect = next == null || previous.id != next.id;
      if (shouldReconnect) {
        await reconnect(next);
      }
    });
    ref.watch(coreRestartSignalProvider);

    yield* _connectionRepo.watchConnectionStatus().doOnData((event) {
      final reconnectProgress = ref.read(reconnectProgressProvider.notifier);
      final updatedProgress = reconnectProgress.state.observe(event);
      if (updatedProgress.coreRecovered && !reconnectProgress.state.coreRecovered) {
        loggy.info("core recovered during reconnect; showing live connection status");
      }
      reconnectProgress.state = updatedProgress;
      if (event case Disconnected(connectionFailure: final _?) when PlatformUtils.isDesktop) {
        Future.microtask(() => ref.read(Preferences.startedByUser.notifier).update(false));
      }
      loggy.info("connection status: ${event.format()}");
    });
  }

  ConnectionRepository get _connectionRepo => ref.read(connectionRepositoryProvider);

  Future<void> mayConnect() async {
    if (state case AsyncData(:final value)) {
      if (value case Disconnected()) return _connect();
    }
  }

  Future<void> toggleConnection() async {
    final haptic = ref.read(hapticServiceProvider.notifier);
    if (state case AsyncError()) {
      await haptic.lightImpact();
      await _connect();
    } else if (state case AsyncData(:final value)) {
      switch (value) {
        case Disconnected():
          await haptic.lightImpact();
          await ref.read(Preferences.startedByUser.notifier).update(true);
          await _connect();
        case Connected() || Checking() || OutboundUnavailable() || CurrentOutboundUnavailable():
          await haptic.mediumImpact();
          await ref.read(Preferences.startedByUser.notifier).update(false);
          await _disconnect();
        default:
          loggy.warning("switching status, debounce");
      }
    }
  }

  Future<void> reconnect(ProfileEntity? profile) async {
    if (state case AsyncData(:final value) when value.isServiceRunning) {
      if (profile == null) {
        loggy.info("no active profile, disconnecting");
        return _disconnect();
      }
      loggy.info("active profile changed, reconnecting");
      final startedByUser = ref.read(Preferences.startedByUser.notifier);
      final disableMemoryLimit = ref.read(Preferences.disableMemoryLimit);
      final connectionRepo = _connectionRepo;
      final dialogNotifier = ref.read(dialogNotifierProvider.notifier);
      final t = ref.read(translationsProvider).requireValue;

      final reconnectProgress = ref.read(reconnectProgressProvider.notifier);
      reconnectProgress.state = reconnectProgress.state.start();
      loggy.info("reconnect started; pending=${reconnectProgress.state.pending}");
      ConnectionFailure? reconnectError;
      try {
        await startedByUser.update(true);
        final result = await connectionRepo.reconnect(profile, disableMemoryLimit).run();
        result.match((err) {
          loggy.warning("error reconnecting", err);
          state = AsyncError(err, StackTrace.current);
          reconnectError = err;
        }, (_) {});
      } finally {
        reconnectProgress.state = reconnectProgress.state.finish();
        loggy.info("reconnect request finished; pending=${reconnectProgress.state.pending}");
      }
      if (reconnectError case final err?) {
        await dialogNotifier.showCustomAlertFromErr(err.present(t));
      }
    }
  }

  Future<void> abortConnection() async {
    if (state case AsyncData(:final value)) {
      switch (value) {
        case Connected() || Checking() || OutboundUnavailable() || CurrentOutboundUnavailable() || Connecting():
          loggy.debug("aborting connection");
          await _disconnect();
        default:
      }
    }
  }

  final _singleStart = SingleCall();

  Future<void> _connect() async {
    await _singleStart.run<void>(
      () async {
        await _connectThrottled();
      },
      onIgnored: () {
        loggy.debug("connect called while another connect/disconnect is still running, ignoring");
      },
    );
  }

  Future<void> _connectThrottled() async {
    final activeProfileFuture = ref.read(activeProfileProvider.future);
    final disableMemoryLimit = ref.read(Preferences.disableMemoryLimit);
    final connectionRepo = _connectionRepo;
    final dialogNotifier = ref.read(dialogNotifierProvider.notifier);
    final t = ref.read(translationsProvider).requireValue;
    final startedByUser = ref.read(Preferences.startedByUser.notifier);

    final activeProfile = await activeProfileFuture;
    if (activeProfile == null) {
      loggy.info("no active profile, not connecting");
      return;
    }
    await connectionRepo.connect(activeProfile, disableMemoryLimit).mapLeft((ConnectionFailure err) async {
      loggy.warning("error connecting", err);
      //Go err is not normal object to see the go errors are string and need to be dumped
      await dialogNotifier.showCustomAlertFromErr(err.present(t));
      loggy.warning(err);
      if (err.toString().contains("panic")) {
        await Sentry.captureException(Exception(err.toString()));
      }
      await startedByUser.update(false);
      state = AsyncError(err, StackTrace.current);
    }).run();
  }

  Future<void> _disconnect() async {
    final connectionRepo = _connectionRepo;
    final dialogNotifier = ref.read(dialogNotifierProvider.notifier);
    final t = ref.read(translationsProvider).requireValue;

    await connectionRepo.disconnect().mapLeft((err) {
      loggy.warning("error disconnecting", err);
      dialogNotifier.showCustomAlertFromErr(err.present(t));
      state = AsyncError(err, StackTrace.current);
    }).run();
  }
}

@Riverpod(keepAlive: true)
Future<bool> serviceRunning(Ref ref) async {
  // ref.watch(coreRestartSignalProvider);
  return await ref
      .watch(connectionNotifierProvider.selectAsync((data) => data.isServiceRunning))
      .onError((error, stackTrace) => false);
}

class SingleCall {
  bool _running = false;

  Future<T> run<T>(Future<T> Function() task, {required T Function() onIgnored}) async {
    if (_running) return onIgnored();

    _running = true;
    try {
      return await task();
    } finally {
      _running = false;
    }
  }
}
