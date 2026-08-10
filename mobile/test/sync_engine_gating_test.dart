// Unit tests for the sync engine's HTTP gating logic.
//
// We can't easily test the periodic timer at 45s, but we can verify the
// "do nothing if not authenticated" guard and the re-entrancy protection,
// both of which were critical for the recent fixes.

import 'dart:async';

import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/core/config.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/sync/sync_engine.dart';
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
