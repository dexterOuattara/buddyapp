import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/connectivity.dart';
import '../db/app_database.dart';
import '../features/agenda/agenda_reminder_service.dart';
import '../features/auth/auth_session_store.dart';
import '../features/courses/course_progress.dart';
import '../sync/background_sync.dart';
import '../sync/sync_engine.dart';

/// Global object graph for the app.

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient();
  ref.onDispose(api.dispose);
  return api;
});

final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final api = ref.watch(apiClientProvider);
  final connectivity = ref.watch(connectivityProvider);
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    api: api,
    onlineCheck: () => connectivity.isOnline,
    scheduleBackgroundRetry: BackgroundSyncScheduler.enqueueWhenOnline,
    persistSession: () => AuthSessionStore.persist(api),
  );
  ref.onDispose(engine.dispose);

  // Kick a sync whenever connectivity returns.
  final subscription = connectivity.onConnectivityChanged.listen((online) {
    if (online) engine.sync();
  });
  ref.onDispose(subscription.cancel);

  return engine;
});

/// Emits the current sync phase for status UI.
final syncPhaseProvider = StreamProvider<SyncPhase>((ref) {
  return ref.watch(syncEngineProvider).phaseStream;
});

final agendaReminderServiceProvider = Provider<AgendaReminderService>((ref) {
  return AgendaReminderService();
});

/// Keeps OS notifications aligned with the offline Agenda source of truth.
/// Watching this provider once from the app shell is enough to activate it.
final agendaReminderCoordinatorProvider = Provider<void>((ref) {
  final reminders = ref.watch(agendaReminderServiceProvider);
  ref.listen<AsyncValue<List<AgendaItem>>>(agendaStreamProvider, (_, next) {
    next.whenData((items) {
      // Notification scheduling is best effort and must never block local UX.
      reminders.reconcile(items).ignore();
    });
  }, fireImmediately: true);
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

final courseCatalogRepositoryProvider = Provider<CourseCatalogRepository>((
  ref,
) {
  return CourseCatalogRepository(ref.watch(databaseProvider));
});

final courseCatalogProvider = StreamProvider<CourseCatalogSnapshot>((ref) {
  return ref.watch(courseCatalogRepositoryProvider).watch();
});
