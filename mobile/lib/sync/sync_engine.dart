import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../db/app_database.dart';

enum SyncPhase { idle, pushing, pulling, done, offline, error }

/// Reconciles local SQLite with the backend. Runs when connectivity returns,
/// when the app is foregrounded, on a periodic timer, or on demand.
class SyncEngine {
  SyncEngine({required this.db, required this.api}) {
    _timer = Timer.periodic(Config.syncPollInterval, (_) => sync());
  }

  final AppDatabase db;
  final ApiClient api;

  final _phase = StreamController<SyncPhase>.broadcast();
  Stream<SyncPhase> get phaseStream => _phase.stream;
  SyncPhase currentPhase = SyncPhase.idle;

  bool _running = false;
  Timer? _timer;

  void _setPhase(SyncPhase p) {
    currentPhase = p;
    _phase.add(p);
  }

  /// Stops the periodic timer. Called from the provider on app shutdown.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _phase.close();
  }

  /// Full sync pass: push local changes, then pull remote changes.
  Future<void> sync() async {
    if (_running) return;
    _running = true;
    try {
      if (!api.isAuthenticated) {
        _setPhase(SyncPhase.idle);
        return;
      }
      _setPhase(SyncPhase.pushing);
      await _pushStructure();
      await _pushRecordings();
      _setPhase(SyncPhase.pulling);
      await _pullStructure();
      await _pullRecordings();
      await _pullStudy();
      _setPhase(SyncPhase.done);
    } on SocketException {
      _setPhase(SyncPhase.offline);
    } on ApiException catch (e) {
      _setPhase(SyncPhase.error);
      _lastError = e.toString();
    } catch (e) {
      _setPhase(SyncPhase.error);
      _lastError = e.toString();
    } finally {
      _running = false;
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  // ----------------------------------------------------------------- cursors

  Future<int?> _cursor(String key) async {
    final row = await (db.select(db.meta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  Future<void> _setCursor(String key, int? value) async {
    if (value == null) return;
    await db.into(db.meta).insertOnConflictUpdate(
        MetaCompanion.insert(key: key, value: '$value'));
  }

  // -------------------------------------------------------------------- push

  Future<void> _pushStructure() async {
    // Dependency order: agenda & courses first, then lessons, then chapters.
    await _pushTable(
      select: () => (db.select(db.courses)
            ..where((t) => t.pendingSync.equals(true)))
          .get(),
      pushOne: (c) => api.upsertCourse({
        'client_uuid': c.clientUuid,
        'title': c.title,
        'description': c.description,
        'deleted': c.deleted,
      }),
      markSynced: (c, server) => (db.update(db.courses)
            ..where((t) => t.clientUuid.equals(c.clientUuid)))
          .write(CoursesCompanion(
        pendingSync: const Value(false),
        syncVersion: Value(_asInt(server['sync_version'])),
        updatedAt: Value(DateTime.now()),
      )),
    );

    await _pushTable(
      select: () => (db.select(db.agendaItems)
            ..where((t) => t.pendingSync.equals(true)))
          .get(),
      pushOne: (a) => api.upsertAgenda({
        'client_uuid': a.clientUuid,
        'title': a.title,
        'notes': a.notes,
        'starts_at': a.startsAt?.toIso8601String(),
        'ends_at': a.endsAt?.toIso8601String(),
        'deleted': a.deleted,
      }),
      markSynced: (a, server) => (db.update(db.agendaItems)
            ..where((t) => t.clientUuid.equals(a.clientUuid)))
          .write(AgendaItemsCompanion(
        pendingSync: const Value(false),
        syncVersion: Value(_asInt(server['sync_version'])),
        updatedAt: Value(DateTime.now()),
      )),
    );

    await _pushTable(
      select: () => (db.select(db.lessons)
            ..where((t) => t.pendingSync.equals(true)))
          .get(),
      pushOne: (l) => api.upsertLesson({
        'client_uuid': l.clientUuid,
        'course_client_uuid': l.courseClientUuid,
        'title': l.title,
        'position': l.position,
        'deleted': l.deleted,
      }),
      markSynced: (l, server) => (db.update(db.lessons)
            ..where((t) => t.clientUuid.equals(l.clientUuid)))
          .write(LessonsCompanion(
        pendingSync: const Value(false),
        syncVersion: Value(_asInt(server['sync_version'])),
        updatedAt: Value(DateTime.now()),
      )),
    );

    await _pushTable(
      select: () => (db.select(db.chapters)
            ..where((t) => t.pendingSync.equals(true)))
          .get(),
      pushOne: (c) => api.upsertChapter({
        'client_uuid': c.clientUuid,
        'lesson_client_uuid': c.lessonClientUuid,
        'title': c.title,
        'position': c.position,
        'deleted': c.deleted,
      }),
      markSynced: (c, server) => (db.update(db.chapters)
            ..where((t) => t.clientUuid.equals(c.clientUuid)))
          .write(ChaptersCompanion(
        pendingSync: const Value(false),
        syncVersion: Value(_asInt(server['sync_version'])),
        updatedAt: Value(DateTime.now()),
      )),
    );
  }

  Future<void> _pushTable<T>({
    required Future<List<T>> Function() select,
    required Future<Map<String, dynamic>> Function(T) pushOne,
    required Future<void> Function(T, Map<String, dynamic>) markSynced,
  }) async {
    final rows = await select();
    for (final row in rows) {
      try {
        final server = await pushOne(row);
        await markSynced(row, server);
      } on ApiException {
        // Parent may not exist yet or a validation failed — skip for now;
        // the row stays pending and retries on the next pass.
        continue;
      }
    }
  }

  /// Resumable, chunked upload of recordings that are ready to leave the device.
  Future<void> _pushRecordings() async {
    final pending = await (db.select(db.recordings)
          ..where((t) => t.status.isIn([
                'pending_sync',
                'uploading',
              ])))
        .get();

    for (final rec in pending) {
      final file = File(rec.localPath);
      if (!await file.exists()) {
        await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
            .write(const RecordingsCompanion(status: Value('failed')));
        continue;
      }

      await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
          .write(const RecordingsCompanion(status: Value('uploading')));

      try {
        final session = await api.createUpload({
          'client_uuid': rec.clientUuid,
          'chapter_client_uuid': rec.chapterClientUuid,
          'duration_secs': rec.durationSecs,
          'file_name': rec.fileName ?? '${rec.clientUuid}.m4a',
        });
        final uploadId = session['upload_id'] as String;
        var offset = _asInt(session['offset']);

        final stream = file.openRead();
        var chunkStart = offset;
        await for (final chunk in stream) {
          // openRead yields sequential slices; only send from the resume offset.
          final res = await api.uploadChunk(uploadId, chunkStart, chunk);
          chunkStart += chunk.length;
          offset = _asInt(res['offset']);
          await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
              .write(RecordingsCompanion(uploadedBytes: Value(offset)));
        }

        final completed = await api.completeUpload(uploadId);
        await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
            .write(RecordingsCompanion(
          status: const Value('processing'),
          serverRecordingId: Value(completed['id'] as String?),
        ));
      } on ApiException {
        await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
            .write(const RecordingsCompanion(status: Value('pending_sync')));
      }
    }
  }

  // -------------------------------------------------------------------- pull

  Future<void> _pullStructure() async {
    // Courses.
    var since = await _cursor('courses');
    final courses = await api.listCourses(since: since);
    await _applyDelta(courses, (item) async {
      // InsertMode.insertOrReplace: local rows are keyed by client_uuid in
      // every query — auto-increment `id` is only an internal Drift handle,
      // so replacing it on conflict is safe and avoids the need to declare
      // the conflict target manually.
      await db.into(db.courses).insert(
        CoursesCompanion.insert(
          clientUuid: item['client_uuid'] as String,
          serverId: Value(item['id'] as String?),
          title: item['title'] as String,
          description: Value(item['description'] as String?),
          deleted: Value(item['deleted_at'] != null),
          pendingSync: const Value(false),
          syncVersion: Value(_asInt(item['sync_version'])),
        ),
        mode: InsertMode.insertOrReplace,
      );
      await _maybeBumpCursor('courses', _asInt(item['sync_version']));
    });

    // Lessons.
    since = await _cursor('lessons');
    final lessons = await api.listLessons(since: since);
    await _applyDelta(lessons, (item) async {
      final courseUuid =
          await _courseClientUuidByServerId(item['course_id'] as String?);
      if (courseUuid == null) return;
      await db.into(db.lessons).insert(
        LessonsCompanion.insert(
          clientUuid: item['client_uuid'] as String,
          serverId: Value(item['id'] as String?),
          courseClientUuid: courseUuid,
          title: item['title'] as String,
          position: Value(_asInt(item['position'])),
          deleted: Value(item['deleted_at'] != null),
          pendingSync: const Value(false),
          syncVersion: Value(_asInt(item['sync_version'])),
        ),
        mode: InsertMode.insertOrReplace,
      );
      await _maybeBumpCursor('lessons', _asInt(item['sync_version']));
    });

    // Chapters.
    since = await _cursor('chapters');
    final chapters = await api.listChapters(since: since);
    await _applyDelta(chapters, (item) async {
      final lessonUuid =
          await _lessonClientUuidByServerId(item['lesson_id'] as String?);
      if (lessonUuid == null) return;
      await db.into(db.chapters).insert(
        ChaptersCompanion.insert(
          clientUuid: item['client_uuid'] as String,
          serverId: Value(item['id'] as String?),
          lessonClientUuid: lessonUuid,
          title: item['title'] as String,
          position: Value(_asInt(item['position'])),
          deleted: Value(item['deleted_at'] != null),
          pendingSync: const Value(false),
          syncVersion: Value(_asInt(item['sync_version'])),
        ),
        mode: InsertMode.insertOrReplace,
      );
      await _maybeBumpCursor('chapters', _asInt(item['sync_version']));
    });

    // Agenda.
    since = await _cursor('agenda');
    final agenda = await api.listAgenda(since: since);
    await _applyDelta(agenda, (item) async {
      await db.into(db.agendaItems).insert(
        AgendaItemsCompanion.insert(
          clientUuid: item['client_uuid'] as String,
          serverId: Value(item['id'] as String?),
          title: item['title'] as String,
          notes: Value(item['notes'] as String?),
          startsAt: Value(_asDate(item['starts_at'])),
          endsAt: Value(_asDate(item['ends_at'])),
          deleted: Value(item['deleted_at'] != null),
          pendingSync: const Value(false),
          syncVersion: Value(_asInt(item['sync_version'])),
        ),
        mode: InsertMode.insertOrReplace,
      );
      await _maybeBumpCursor('agenda', _asInt(item['sync_version']));
    });
  }

  Future<void> _pullRecordings() async {
    final since = await _cursor('recordings');
    final delta = await api.listRecordings(since: since);
    await _applyDelta(delta, (item) async {
      final clientUuid = item['client_uuid'] as String?;
      if (clientUuid == null) return;
      final status = item['status'] as String? ?? 'uploaded';
      await (db.update(db.recordings)
            ..where((t) => t.clientUuid.equals(clientUuid)))
          .write(RecordingsCompanion(
        status: Value(_mapServerStatus(status)),
        serverRecordingId: Value(item['id'] as String?),
      ));
      await _maybeBumpCursor('recordings', _asInt(item['sync_version']));
    });
  }

  Future<void> _pullStudy() async {
    final since = await _cursor('study');
    final delta = await api.listStudy(since: since);

    for (final s in (delta['summaries'] as List? ?? const [])) {
      final item = s as Map<String, dynamic>;
      final chapterUuid =
          await _chapterClientUuidByServerId(item['chapter_id'] as String?);
      if (chapterUuid == null) continue;
      // Local summaries table has no UNIQUE constraint on chapterClientUuid,
      // so we let each insert allocate a new id. This is fine for v1; a
      // proper "latest summary per chapter" view should add a UNIQUE
      // constraint and target it.
      await db.into(db.summaries).insert(SummariesCompanion.insert(
        chapterClientUuid: chapterUuid,
        contentMd: item['content_md'] as String,
        status: const Value('approved'),
        syncVersion: Value(_asInt(item['sync_version'])),
      ));
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }

    for (final e in (delta['exercises'] as List? ?? const [])) {
      final item = e as Map<String, dynamic>;
      final chapterUuid =
          await _chapterClientUuidByServerId(item['chapter_id'] as String?);
      if (chapterUuid == null) continue;
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
        chapterClientUuid: chapterUuid,
        itemsJson: jsonEncode(item['items']),
        status: const Value('approved'),
        syncVersion: Value(_asInt(item['sync_version'])),
      ));
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }

    for (final qz in (delta['quizzes'] as List? ?? const [])) {
      final item = qz as Map<String, dynamic>;
      final chapterUuid =
          await _chapterClientUuidByServerId(item['chapter_id'] as String?);
      if (chapterUuid == null) continue;
      await db.into(db.quizzes).insert(QuizzesCompanion.insert(
        chapterClientUuid: chapterUuid,
        questionsJson: jsonEncode(item['questions']),
        status: const Value('approved'),
        syncVersion: Value(_asInt(item['sync_version'])),
      ));
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }
  }

  // ------------------------------------------------------------------ mapping

  Future<void> _applyDelta(
    Map<String, dynamic> delta,
    Future<void> Function(Map<String, dynamic>) apply,
  ) async {
    final items = (delta['items'] as List? ?? const []);
    for (final raw in items) {
      await apply(raw as Map<String, dynamic>);
    }
  }

  Future<void> _maybeBumpCursor(String key, int version) async {
    final current = await _cursor(key) ?? 0;
    if (version > current) await _setCursor(key, version);
  }

  String _mapServerStatus(String server) {
    switch (server) {
      case 'uploaded':
        return 'synced';
      case 'processing':
        return 'processing';
      case 'ready':
        return 'ready';
      case 'failed':
      case 'blocked':
        return 'failed';
      default:
        return 'synced';
    }
  }

  /// Resolve a locally-known client UUID from a server-side id. Returns null
  /// when the parent row isn't on this device yet (skipped this pass).
  Future<String?> _courseClientUuidByServerId(String? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(db.courses)
          ..where((t) => t.serverId.equals(serverId)))
        .getSingleOrNull();
    return row?.clientUuid;
  }

  Future<String?> _lessonClientUuidByServerId(String? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(db.lessons)
          ..where((t) => t.serverId.equals(serverId)))
        .getSingleOrNull();
    return row?.clientUuid;
  }

  Future<String?> _chapterClientUuidByServerId(String? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(db.chapters)
          ..where((t) => t.serverId.equals(serverId)))
        .getSingleOrNull();
    return row?.clientUuid;
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  DateTime? _asDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
