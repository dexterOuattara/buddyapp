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

  /// Queues a single retry that remains dormant until Android detects a
  /// network. Re-registering replaces the pending retry instead of stacking.
  static Future<void> enqueueWhenOnline() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().registerOneOffTask(
      _networkRetryUniqueName,
      backgroundSyncTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
      tag: _syncTaskTag,
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
      return switch (engine.currentPhase) {
        SyncPhase.error || SyncPhase.offline => false,
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
