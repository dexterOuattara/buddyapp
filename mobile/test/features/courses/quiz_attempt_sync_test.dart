import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/sync/sync_engine.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quiz attempt is pushed idempotently and marked synchronized', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final api = _QuizAttemptApi();
    final engine = SyncEngine(db: db, api: api);
    addTearDown(() async {
      engine.dispose();
      await db.close();
    });

    await db
        .into(db.quizzes)
        .insert(
          QuizzesCompanion.insert(
            serverId: const Value('quiz-server'),
            chapterClientUuid: 'chapter-local',
            questionsJson: '[]',
          ),
        );
    await db
        .into(db.quizAttempts)
        .insert(
          QuizAttemptsCompanion.insert(
            clientUuid: 'attempt-client',
            quizServerId: 'quiz-server',
            chapterClientUuid: 'chapter-local',
            score: 8,
            total: 10,
            answersJson: '[{"correct":true}]',
          ),
        );

    await engine.sync();

    expect(api.recordedBody?['client_uuid'], 'attempt-client');
    expect(api.recordedBody?['score'], 8);
    final attempt = await db.select(db.quizAttempts).getSingle();
    expect(attempt.serverId, 'attempt-server');
    expect(attempt.pendingSync, false);
  });
}

class _QuizAttemptApi extends ApiClient {
  _QuizAttemptApi() {
    accessToken = 'test-token';
  }

  Map<String, dynamic>? recordedBody;

  Map<String, dynamic> get _emptyDelta => const {
    'items': <dynamic>[],
    'cursor': 0,
    'has_more': false,
  };

  @override
  Future<Map<String, dynamic>> recordQuizAttempt(
    String quizId,
    Map<String, dynamic> body,
  ) async {
    recordedBody = body;
    return {
      'id': 'attempt-server',
      'client_uuid': body['client_uuid'],
      'quiz_id': quizId,
      'score': body['score'],
      'total': body['total'],
      'answers': body['answers'],
      'taken_at': '2026-08-09T12:00:00Z',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listQuizAttempts(String quizId) async => [
    {
      'id': 'attempt-server',
      'client_uuid': 'attempt-client',
      'quiz_id': quizId,
      'score': 8,
      'total': 10,
      'answers': [
        {'correct': true},
      ],
      'taken_at': '2026-08-09T12:00:00Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> listAgenda({int? since}) async => _emptyDelta;

  @override
  Future<Map<String, dynamic>> listCourses({int? since}) async => _emptyDelta;

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
