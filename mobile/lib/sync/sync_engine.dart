import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../db/app_database.dart';

enum SyncPhase { idle, pushing, pulling, done, offline, error }

typedef OnlineCheck = Future<bool> Function();
typedef BackgroundRetryScheduler = Future<void> Function();
typedef SessionPersistence = Future<void> Function();

/// Reconciles local SQLite with the backend. Runs when connectivity returns,
/// when the app is foregrounded, on a periodic timer, or on demand.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.api,
    this.enableForegroundTimer = true,
    this.onlineCheck,
    this.scheduleBackgroundRetry,
    this.persistSession,
  }) {
    if (enableForegroundTimer) {
      _timer = Timer.periodic(Config.syncPollInterval, (_) => sync());
    }
  }

  final AppDatabase db;
  final ApiClient api;
  final bool enableForegroundTimer;
  final OnlineCheck? onlineCheck;
  final BackgroundRetryScheduler? scheduleBackgroundRetry;
  final SessionPersistence? persistSession;

  final _phase = StreamController<SyncPhase>.broadcast();
  Stream<SyncPhase> get phaseStream => _phase.stream;
  SyncPhase currentPhase = SyncPhase.idle;

  bool _running = false;
  Timer? _timer;
  String? _leaseValue;

  static const _leaseKey = 'sync.lease';
  static const _leaseLifetime = Duration(minutes: 20);

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
  Future<void> sync({bool force = false}) async {
    if (_running) return;
    _running = true;
    var leaseAcquired = false;
    try {
      if (!api.isAuthenticated) {
        _setPhase(SyncPhase.idle);
        return;
      }
      if (!force) {
        final check = onlineCheck;
        if (check != null && !await check()) {
          _setPhase(SyncPhase.offline);
          await _queueBackgroundRetry();
          return;
        }
      }
      leaseAcquired = await _acquireLease();
      if (!leaseAcquired) {
        // Another isolate (foreground or WorkManager) is already syncing the
        // same SQLite database. Its idempotent pass is allowed to finish.
        _setPhase(SyncPhase.idle);
        return;
      }
      _setPhase(SyncPhase.pushing);
      await _pushStructure();
      await _pushRecordings();
      await _pushQuizAttempts();
      _setPhase(SyncPhase.pulling);
      await _pullStructure();
      await _pullRecordings();
      await _pullStudy();
      await _pullQuizAttempts();
      _setPhase(SyncPhase.done);
    } on SocketException {
      _setPhase(SyncPhase.offline);
      await _queueBackgroundRetry();
    } on ApiException catch (e) {
      _setPhase(SyncPhase.error);
      _lastError = e.toString();
    } catch (e) {
      _setPhase(SyncPhase.error);
      _lastError = e.toString();
    } finally {
      try {
        await persistSession?.call();
      } catch (_) {
        // A sync result must not be turned into a failure because secure local
        // token persistence was temporarily unavailable.
      }
      if (leaseAcquired) await _releaseLease();
      _running = false;
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<void> _queueBackgroundRetry() async {
    try {
      await scheduleBackgroundRetry?.call();
    } catch (_) {
      // Scheduling is best effort. The foreground timer and periodic Android
      // worker remain available even if this one-off enqueue fails.
    }
  }

  Future<bool> _acquireLease() async {
    var acquired = false;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final value = '$now:${identityHashCode(this)}';
    await db.transaction(() async {
      final current = await (db.select(
        db.meta,
      )..where((row) => row.key.equals(_leaseKey))).getSingleOrNull();
      final timestamp = current == null
          ? null
          : int.tryParse(current.value.split(':').first);
      final leaseIsFresh =
          timestamp != null && now - timestamp < _leaseLifetime.inMilliseconds;
      if (leaseIsFresh) return;
      await db
          .into(db.meta)
          .insertOnConflictUpdate(
            MetaCompanion.insert(key: _leaseKey, value: value),
          );
      acquired = true;
      _leaseValue = value;
    });
    return acquired;
  }

  Future<void> _releaseLease() async {
    final value = _leaseValue;
    if (value == null) return;
    await (db.delete(db.meta)
          ..where((row) => row.key.equals(_leaseKey) & row.value.equals(value)))
        .go();
    _leaseValue = null;
  }

  // ----------------------------------------------------------------- cursors

  Future<int?> _cursor(String key) async {
    final row = await (db.select(
      db.meta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  Future<void> _setCursor(String key, int? value) async {
    if (value == null) return;
    await db
        .into(db.meta)
        .insertOnConflictUpdate(
          MetaCompanion.insert(key: key, value: '$value'),
        );
  }

  // -------------------------------------------------------------------- push

  Future<void> _pushStructure() async {
    // Dependency order: agenda & courses first, then lessons, then chapters.
    await _pushTable(
      select: () => (db.select(
        db.courses,
      )..where((t) => t.pendingSync.equals(true))).get(),
      pushOne: (c) => api.upsertCourse({
        'client_uuid': c.clientUuid,
        'title': c.title,
        'description': c.description,
        'deleted': c.deleted,
      }),
      markSynced: (c, server) =>
          (db.update(
            db.courses,
          )..where((t) => t.clientUuid.equals(c.clientUuid))).write(
            CoursesCompanion(
              pendingSync: const Value(false),
              syncVersion: Value(_asInt(server['sync_version'])),
              updatedAt: Value(DateTime.now()),
            ),
          ),
    );

    await _pushTable(
      select: () => (db.select(
        db.agendaItems,
      )..where((t) => t.pendingSync.equals(true))).get(),
      pushOne: (a) => api.upsertAgenda({
        'client_uuid': a.clientUuid,
        'title': a.title,
        'kind': a.kind,
        'subject': a.subject,
        'notes': a.notes,
        'location': a.location,
        'starts_at': a.startsAt?.toUtc().toIso8601String(),
        'ends_at': a.endsAt?.toUtc().toIso8601String(),
        'recurrence': a.recurrence,
        'recurrence_until': a.recurrenceUntil?.toUtc().toIso8601String(),
        'reminder_minutes': a.reminderMinutes,
        'chapter_client_uuid': a.chapterClientUuid,
        'deleted': a.deleted,
      }),
      markSynced: (a, server) =>
          (db.update(
            db.agendaItems,
          )..where((t) => t.clientUuid.equals(a.clientUuid))).write(
            AgendaItemsCompanion(
              pendingSync: const Value(false),
              syncVersion: Value(_asInt(server['sync_version'])),
              updatedAt: Value(DateTime.now()),
            ),
          ),
    );

    await _pushTable(
      select: () => (db.select(
        db.lessons,
      )..where((t) => t.pendingSync.equals(true))).get(),
      pushOne: (l) => api.upsertLesson({
        'client_uuid': l.clientUuid,
        'course_client_uuid': l.courseClientUuid,
        'title': l.title,
        'position': l.position,
        'deleted': l.deleted,
      }),
      markSynced: (l, server) =>
          (db.update(
            db.lessons,
          )..where((t) => t.clientUuid.equals(l.clientUuid))).write(
            LessonsCompanion(
              pendingSync: const Value(false),
              syncVersion: Value(_asInt(server['sync_version'])),
              updatedAt: Value(DateTime.now()),
            ),
          ),
    );

    await _pushTable(
      select: () => (db.select(
        db.chapters,
      )..where((t) => t.pendingSync.equals(true))).get(),
      pushOne: (c) => api.upsertChapter({
        'client_uuid': c.clientUuid,
        'lesson_client_uuid': c.lessonClientUuid,
        'title': c.title,
        'position': c.position,
        'deleted': c.deleted,
      }),
      markSynced: (c, server) =>
          (db.update(
            db.chapters,
          )..where((t) => t.clientUuid.equals(c.clientUuid))).write(
            ChaptersCompanion(
              pendingSync: const Value(false),
              syncVersion: Value(_asInt(server['sync_version'])),
              updatedAt: Value(DateTime.now()),
            ),
          ),
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
    final pending = await (db.select(
      db.recordings,
    )..where((t) => t.status.isIn(['pending_sync', 'uploading']))).get();

    for (final rec in pending) {
      final file = File(rec.localPath);
      if (!await file.exists()) {
        await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
            .write(const RecordingsCompanion(status: Value('failed')));
        continue;
      }

      await (db.update(db.recordings)..where((t) => t.id.equals(rec.id))).write(
        const RecordingsCompanion(status: Value('uploading')),
      );

      try {
        final session = await api.createUpload({
          'client_uuid': rec.clientUuid,
          'chapter_client_uuid': rec.chapterClientUuid,
          'duration_secs': rec.durationSecs,
          'file_name': rec.fileName ?? '${rec.clientUuid}.m4a',
        });
        final uploadId = session['upload_id'] as String;
        var offset = _asInt(session['offset']);

        final stream = file.openRead(offset);
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
        await (db.update(
          db.recordings,
        )..where((t) => t.id.equals(rec.id))).write(
          RecordingsCompanion(
            status: const Value('processing'),
            serverRecordingId: Value(completed['id'] as String?),
          ),
        );
      } on ApiException {
        await (db.update(db.recordings)..where((t) => t.id.equals(rec.id)))
            .write(const RecordingsCompanion(status: Value('pending_sync')));
      }
    }
  }

  Future<void> _pushQuizAttempts() async {
    final pending = await (db.select(
      db.quizAttempts,
    )..where((t) => t.pendingSync.equals(true))).get();

    for (final attempt in pending) {
      if (attempt.quizServerId.isEmpty) continue;
      try {
        final server = await api.recordQuizAttempt(attempt.quizServerId, {
          'client_uuid': attempt.clientUuid,
          'score': attempt.score,
          'total': attempt.total,
          'answers': jsonDecode(attempt.answersJson),
        });
        await (db.update(
          db.quizAttempts,
        )..where((t) => t.clientUuid.equals(attempt.clientUuid))).write(
          QuizAttemptsCompanion(
            serverId: Value(server['id'] as String?),
            pendingSync: const Value(false),
          ),
        );
      } on ApiException {
        // The quiz may not be available server-side yet. Keep the local
        // result pending and retry during the next sync pass.
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
      await db
          .into(db.courses)
          .insert(
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
      final courseUuid = await _courseClientUuidByServerId(
        item['course_id'] as String?,
      );
      if (courseUuid == null) return;
      await db
          .into(db.lessons)
          .insert(
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
      final lessonUuid = await _lessonClientUuidByServerId(
        item['lesson_id'] as String?,
      );
      if (lessonUuid == null) return;
      await db
          .into(db.chapters)
          .insert(
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
      await db
          .into(db.agendaItems)
          .insert(
            AgendaItemsCompanion.insert(
              clientUuid: item['client_uuid'] as String,
              serverId: Value(item['id'] as String?),
              title: item['title'] as String,
              kind: Value(item['kind'] as String? ?? 'course'),
              subject: Value(item['subject'] as String?),
              notes: Value(item['notes'] as String?),
              location: Value(item['location'] as String?),
              startsAt: Value(_asDate(item['starts_at'])),
              endsAt: Value(_asDate(item['ends_at'])),
              recurrence: Value(item['recurrence'] as String? ?? 'none'),
              recurrenceUntil: Value(_asDate(item['recurrence_until'])),
              reminderMinutes: Value(_asNullableInt(item['reminder_minutes'])),
              chapterClientUuid: Value(item['chapter_client_uuid'] as String?),
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
      await (db.update(
        db.recordings,
      )..where((t) => t.clientUuid.equals(clientUuid))).write(
        RecordingsCompanion(
          status: Value(_mapServerStatus(status)),
          serverRecordingId: Value(item['id'] as String?),
        ),
      );
      await _maybeBumpCursor('recordings', _asInt(item['sync_version']));
    });
  }

  Future<void> _pullStudy() async {
    final since = await _cursor('study');
    final delta = await api.listStudy(since: since);

    for (final raw in (delta['transcripts'] as List? ?? const [])) {
      final item = raw as Map<String, dynamic>;
      final recordingServerId = item['recording_id'] as String?;
      final recordingClientUuid = await _recordingClientUuidByServerId(
        recordingServerId,
      );
      if (recordingServerId == null || recordingClientUuid == null) continue;
      final serverId = item['id'] as String?;
      if (serverId == null) continue;
      final existing = await (db.select(
        db.transcripts,
      )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
      final companion = TranscriptsCompanion(
        serverId: Value(serverId),
        recordingServerId: Value(recordingServerId),
        recordingClientUuid: Value(recordingClientUuid),
        content: Value(item['content'] as String? ?? ''),
        language: Value(item['language'] as String?),
        segmentsJson: Value(jsonEncode(item['segments'] ?? const [])),
        syncVersion: Value(_asInt(item['sync_version'])),
      );
      if (existing == null) {
        await db.into(db.transcripts).insert(companion);
      } else {
        await (db.update(
          db.transcripts,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      }
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }

    for (final s in (delta['summaries'] as List? ?? const [])) {
      final item = s as Map<String, dynamic>;
      final chapterUuid = await _chapterClientUuidByServerId(
        item['chapter_id'] as String?,
      );
      if (chapterUuid == null) continue;
      final serverId = item['id'] as String?;
      final existing = serverId == null
          ? null
          : await (db.select(
              db.summaries,
            )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
      final companion = SummariesCompanion(
        serverId: Value(serverId),
        recordingServerId: Value(item['recording_id'] as String?),
        chapterClientUuid: Value(chapterUuid),
        contentMd: Value(item['content_md'] as String),
        structuredJson: Value(
          item['structured_content'] == null
              ? null
              : jsonEncode(item['structured_content']),
        ),
        status: const Value('approved'),
        syncVersion: Value(_asInt(item['sync_version'])),
      );
      if (existing == null) {
        await db.into(db.summaries).insert(companion);
      } else {
        await (db.update(
          db.summaries,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      }
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }

    for (final e in (delta['exercises'] as List? ?? const [])) {
      final item = e as Map<String, dynamic>;
      final chapterUuid = await _chapterClientUuidByServerId(
        item['chapter_id'] as String?,
      );
      if (chapterUuid == null) continue;
      final serverId = item['id'] as String?;
      final existing = serverId == null
          ? null
          : await (db.select(
              db.exercises,
            )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
      final companion = ExercisesCompanion(
        serverId: Value(serverId),
        recordingServerId: Value(item['recording_id'] as String?),
        chapterClientUuid: Value(chapterUuid),
        itemsJson: Value(jsonEncode(item['items'])),
        status: const Value('approved'),
        syncVersion: Value(_asInt(item['sync_version'])),
      );
      if (existing == null) {
        await db.into(db.exercises).insert(companion);
      } else {
        await (db.update(
          db.exercises,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      }
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }

    for (final qz in (delta['quizzes'] as List? ?? const [])) {
      final item = qz as Map<String, dynamic>;
      final chapterUuid = await _chapterClientUuidByServerId(
        item['chapter_id'] as String?,
      );
      if (chapterUuid == null) continue;
      final serverId = item['id'] as String?;
      final existing = serverId == null
          ? null
          : await (db.select(
              db.quizzes,
            )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
      final companion = QuizzesCompanion(
        serverId: Value(serverId),
        recordingServerId: Value(item['recording_id'] as String?),
        chapterClientUuid: Value(chapterUuid),
        questionsJson: Value(jsonEncode(item['questions'])),
        status: const Value('approved'),
        syncVersion: Value(_asInt(item['sync_version'])),
      );
      if (existing == null) {
        await db.into(db.quizzes).insert(companion);
      } else {
        await (db.update(
          db.quizzes,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      }
      if (serverId != null) {
        await (db.update(db.quizAttempts)..where(
              (t) =>
                  t.chapterClientUuid.equals(chapterUuid) &
                  t.quizServerId.equals(''),
            ))
            .write(QuizAttemptsCompanion(quizServerId: Value(serverId)));
      }
      await _maybeBumpCursor('study', _asInt(item['sync_version']));
    }
  }

  Future<void> _pullQuizAttempts() async {
    final quizzes = await (db.select(
      db.quizzes,
    )..where((q) => q.serverId.isNotNull())).get();
    for (final quiz in quizzes) {
      final quizServerId = quiz.serverId;
      if (quizServerId == null) continue;
      final rows = await api.listQuizAttempts(quizServerId);
      for (final item in rows) {
        final clientUuid = item['client_uuid'] as String?;
        if (clientUuid == null) continue;
        final existing = await (db.select(
          db.quizAttempts,
        )..where((t) => t.clientUuid.equals(clientUuid))).getSingleOrNull();
        final companion = QuizAttemptsCompanion(
          clientUuid: Value(clientUuid),
          serverId: Value(item['id'] as String?),
          quizServerId: Value(quizServerId),
          chapterClientUuid: Value(quiz.chapterClientUuid),
          score: Value(_asInt(item['score'])),
          total: Value(_asInt(item['total'])),
          answersJson: Value(jsonEncode(item['answers'] ?? const [])),
          pendingSync: const Value(false),
          takenAt: Value(_asDate(item['taken_at']) ?? DateTime.now()),
        );
        if (existing == null) {
          await db.into(db.quizAttempts).insert(companion);
        } else if (!existing.pendingSync) {
          await (db.update(
            db.quizAttempts,
          )..where((t) => t.id.equals(existing.id))).write(companion);
        }
      }
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
    final row = await (db.select(
      db.courses,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    return row?.clientUuid;
  }

  Future<String?> _lessonClientUuidByServerId(String? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(
      db.lessons,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    return row?.clientUuid;
  }

  Future<String?> _chapterClientUuidByServerId(String? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(
      db.chapters,
    )..where((t) => t.serverId.equals(serverId))).getSingleOrNull();
    return row?.clientUuid;
  }

  Future<String?> _recordingClientUuidByServerId(String? serverId) async {
    if (serverId == null) return null;
    final row = await (db.select(
      db.recordings,
    )..where((t) => t.serverRecordingId.equals(serverId))).getSingleOrNull();
    return row?.clientUuid;
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  int? _asNullableInt(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse('$v'));

  DateTime? _asDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
