import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/connectivity.dart';
import '../db/app_database.dart';
import '../sync/sync_engine.dart';

/// Global object graph for the app.

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    api: ref.watch(apiClientProvider),
  );
  ref.onDispose(engine.dispose);

  // Kick a sync whenever connectivity returns.
  final connectivity = ref.watch(connectivityProvider);
  connectivity.onConnectivityChanged.listen((online) {
    if (online) engine.sync();
  });

  return engine;
});

/// Emits the current sync phase for status UI.
final syncPhaseProvider = StreamProvider<SyncPhase>((ref) {
  return ref.watch(syncEngineProvider).phaseStream;
});

/// Simple stream providers over the local database.
final coursesStreamProvider = StreamProvider<List<Course>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.courses).watch();
});

final agendaStreamProvider = StreamProvider<List<AgendaItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.agendaItems).watch();
});

final recordingsStreamProvider = StreamProvider<List<Recording>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.recordings).watch();
});
