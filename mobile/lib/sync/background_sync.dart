import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../core/connectivity.dart';
import '../db/app_database.dart';
import '../features/auth/auth_session_store.dart';
import 'sync_engine.dart';

const backgroundSyncTask = 'buddywize.background.sync';
const _periodicSyncUniqueName = 'buddywize-periodic-sync';
const _networkRetryUniqueName = 'buddywize-network-retry-sync';
const _syncTaskTag = 'buddywize-sync';

/// Entry point invoked by Android in a separate isolate, even if the app UI
/// is backgrounded or closed.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if (taskName != backgroundSyncTask) return true;
    return BackgroundSyncRunner.run();
  });
}

abstract final class BackgroundSyncScheduler {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    await Workmanager().initialize(backgroundSyncDispatcher);
    _initialized = true;
  }

  /// Registers one unique periodic task. Android enforces a 15-minute minimum
  /// and waits for a working network before starting it.
  static Future<void> registerForAuthenticatedUser() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().registerPeriodicTask(
      _periodicSyncUniqueName,
      backgroundSyncTask,
      frequency: Config.backgroundSyncInterval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
      tag: _syncTaskTag,
    );
  }

  /// Queues an immediate durable drain of the local sync queue. Android keeps
  /// it across process death and waits for a validated network. `update` maps
  /// to append-or-replace for one-off work, so a new recording never cancels a
  /// worker that is already uploading another recording.
  static Future<void> enqueueWhenOnline() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().registerOneOffTask(
      _networkRetryUniqueName,
      backgroundSyncTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 15),
      tag: _syncTaskTag,
      expedited: true,
      outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'BuddyWize synchronise votre cours',
        notificationText: 'Envoi et traitement en cours…',
        notificationChannelId: 'buddywize_processing',
        notificationChannelName: 'Traitement des cours',
        notificationId: 4102,
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
  }

  static Future<void> cancelForSignedOutUser() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().cancelByUniqueName(_periodicSyncUniqueName);
    await Workmanager().cancelByUniqueName(_networkRetryUniqueName);
  }
}

abstract final class BackgroundSyncRunner {
  static Future<bool> run() async {
    final api = ApiClient();
    AppDatabase? db;
    SyncEngine? engine;
    try {
      final authenticated = await AuthSessionStore.restore(api);
      if (!authenticated) return true;
      if (!await ConnectivityService.checkOnline()) return false;

      await Workmanager().reportProgress(const {
        'stage': 'connecting',
        'progress': 1,
      });

      db = AppDatabase();
      engine = SyncEngine(
        db: db,
        api: api,
        enableForegroundTimer: false,
        onlineCheck: ConnectivityService.checkOnline,
      );
      await engine.sync();

      // A 401 may rotate or invalidate tokens during the background pass.
      await AuthSessionStore.persist(api);
      final pending = await engine.hasActiveRecordingWork();
      await Workmanager().reportProgress({
        'stage': pending ? 'processing' : 'complete',
        'progress': pending ? 75 : 100,
      });
      return switch (engine.currentPhase) {
        SyncPhase.error || SyncPhase.offline => false,
        _ when pending => false,
        _ => true,
      };
    } catch (_) {
      return false;
    } finally {
      engine?.dispose();
      await db?.close();
      api.dispose();
    }
  }
}
