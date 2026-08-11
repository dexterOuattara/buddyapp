// Unit tests for the sync engine's HTTP gating logic.
//
// We can't easily test the periodic timer at 45s, but we can verify the
// "do nothing if not authenticated" guard and the re-entrancy protection,
// both of which were critical for the recent fixes.

import 'dart:async';
import 'dart:io';

import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/core/config.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/sync/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncEngine.sync()', () {
    test('skips entirely when there is no auth token', () async {
      final client = ApiClient();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final engine = SyncEngine(db: db, api: client);
      addTearDown(engine.dispose);

      await engine.sync();

      expect(
        engine.currentPhase,
        SyncPhase.idle,
        reason: 'sync() must NOT proceed when api.isAuthenticated is false',
      );
    });

    test('re-entrancy guard prevents concurrent syncs', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Slow mock that blocks the in-flight sync until we release it.
      final release = Completer<void>();
      final api = _SlowApi(release.future);

      final engine = SyncEngine(db: db, api: api);
      addTearDown(engine.dispose);

      // Fire the first sync — it will be blocked in the slow mock.
      final f1 = engine.sync();
      // Yield once to let f1 progress past the auth check into the await.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Time the second sync — it must return IMMEDIATELY because the
      // _running guard short-circuits before the (slow) network call.
      final sw = Stopwatch()..start();
      await engine.sync();
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(20),
        reason: 'second sync should short-circuit instantly',
      );

      // Now let the first sync complete.
      release.complete();
      await f1;
    });

    test('Timer.periodic is wired to Config.syncPollInterval', () {
      // We don't observe the timer firing here (too slow), but we can at
      // least assert the value we depend on is sane — otherwise the
      // production timer will fire at the wrong rate.
      expect(Config.syncPollInterval, const Duration(seconds: 45));
      expect(Config.backgroundSyncInterval, const Duration(minutes: 15));
    });

    test(
      'offline pass queues one background retry without calling the API',
      () async {
        final client = ApiClient()..accessToken = 'test-token';
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        var retries = 0;
        final engine = SyncEngine(
          db: db,
          api: client,
          enableForegroundTimer: false,
          onlineCheck: () async => false,
          scheduleBackgroundRetry: () async => retries += 1,
        );
        addTearDown(engine.dispose);

        await engine.sync();

        expect(engine.currentPhase, SyncPhase.offline);
        expect(retries, 1);
      },
    );

    test('manual force bypasses a stale offline connectivity result', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      var retries = 0;
      final engine = SyncEngine(
        db: db,
        api: _SlowApi(Future<void>.value()),
        enableForegroundTimer: false,
        onlineCheck: () async => false,
        scheduleBackgroundRetry: () async => retries += 1,
      );
      addTearDown(engine.dispose);

      await engine.sync(force: true);

      expect(engine.currentPhase, SyncPhase.done);
      expect(retries, 0);
    });

    test(
      'completed server upload is reconciled without resending audio',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final dir = await Directory.systemTemp.createTemp(
          'buddywize-completed-upload-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final audio = File('${dir.path}/course.m4a');
        await audio.writeAsBytes([1, 2, 3, 4]);

        await db.into(db.recordings).insert(
          RecordingsCompanion.insert(
            clientUuid: 'recording-client-1',
            chapterClientUuid: 'chapter-client-1',
            localPath: audio.path,
            status: const Value('uploading'),
          ),
        );

        final api = _CompletedUploadApi();
        final engine = SyncEngine(
          db: db,
          api: api,
          enableForegroundTimer: false,
        );
        addTearDown(engine.dispose);

        await engine.sync(force: true);

        final recording = await db.select(db.recordings).getSingle();
        expect(api.uploadChunkCalls, 0);
        expect(api.completeUploadCalls, 0);
        expect(recording.status, 'failed');
        expect(recording.pipelineStage, 'failed');
        expect(recording.serverRecordingId, 'recording-server-1');
        expect(recording.uploadedBytes, 4);
      },
    );
  });
}

class _SlowApi extends ApiClient {
  _SlowApi(this.release) {
    accessToken = 'test-token';
  }

  final Future<void> release;

  Map<String, dynamic> get _emptyDelta => const {
    'items': <dynamic>[],
    'cursor': 0,
    'has_more': false,
  };

  @override
  Future<Map<String, dynamic>> listCourses({int? since}) async {
    await release;
    return _emptyDelta;
  }

  @override
  Future<Map<String, dynamic>> listAgenda({int? since}) async => _emptyDelta;

  @override
  Future<Map<String, dynamic>> listLessons({int? since}) async => _emptyDelta;

  @override
  Future<Map<String, dynamic>> listChapters({int? since}) async => _emptyDelta;

  @override
  Future<Map<String, dynamic>> listRecordings({int? since}) async =>
      _emptyDelta;

  @override
  Future<Map<String, dynamic>> listStudy({int? since}) async => const {
    'summaries': <dynamic>[],
    'exercises': <dynamic>[],
    'quizzes': <dynamic>[],
    'cursor': 0,
  };
}

class _CompletedUploadApi extends _SlowApi {
  _CompletedUploadApi() : super(Future<void>.value());

  int uploadChunkCalls = 0;
  int completeUploadCalls = 0;

  @override
  Future<Map<String, dynamic>> createUpload(Map<String, dynamic> body) async =>
      const {
        'upload_id': 'upload-server-1',
        'offset': 4,
        'completed': true,
        'recording': {
          'id': 'recording-server-1',
          'status': 'failed',
          'pipeline_stage': 'failed',
          'progress_percent': 40,
          'status_message': 'Le traitement doit être relancé',
          'retryable': false,
          'attempt_count': 1,
          'error_code': 'media_runtime_unavailable',
        },
      };

  @override
  Future<Map<String, dynamic>> uploadChunk(
    String uploadId,
    int offset,
    List<int> bytes,
  ) async {
    uploadChunkCalls += 1;
    throw StateError('audio must not be resent');
  }

  @override
  Future<Map<String, dynamic>> completeUpload(String uploadId) async {
    completeUploadCalls += 1;
    throw StateError('recording payload is already in the handshake');
  }
}
