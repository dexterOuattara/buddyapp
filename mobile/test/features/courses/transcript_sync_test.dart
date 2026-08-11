import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/sync/sync_engine.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timed transcript is downloaded and kept in the local database',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _TranscriptApi();
      final engine = SyncEngine(db: db, api: api);
      addTearDown(() async {
        engine.dispose();
        await db.close();
      });

      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              clientUuid: 'chapter-local',
              serverId: const Value('chapter-server'),
              lessonClientUuid: 'lesson-local',
              title: 'Chapitre cumulatif',
              pendingSync: const Value(false),
            ),
          );
      await db
          .into(db.recordings)
          .insert(
            RecordingsCompanion.insert(
              clientUuid: 'recording-local',
              chapterClientUuid: 'chapter-local',
              localPath: '/tmp/lesson.m4a',
              status: const Value('ready'),
              serverRecordingId: const Value('recording-server'),
            ),
          );

      await engine.sync();

      final transcript = await db.select(db.transcripts).getSingle();
      expect(transcript.serverId, 'transcript-server');
      expect(transcript.recordingClientUuid, 'recording-local');
      expect(transcript.content, 'Bonjour à tous.');
      expect(transcript.language, 'fr');
      expect(transcript.segmentsJson, contains('start_ms'));
      expect(transcript.segmentsJson, contains('"words"'));
      expect(transcript.segmentsJson, contains('"text":"Bonjour"'));
      expect(transcript.syncVersion, 42);

      final summary = await db.select(db.summaries).getSingle();
      final exercise = await db.select(db.exercises).getSingle();
      final quiz = await db.select(db.quizzes).getSingle();
      expect(summary.generationId, 'generation-server');
      expect(exercise.generationId, summary.generationId);
      expect(quiz.generationId, summary.generationId);
    },
  );
}

class _TranscriptApi extends ApiClient {
  _TranscriptApi() {
    accessToken = 'test-token';
  }

  Map<String, dynamic> get _emptyDelta => const {
    'items': <dynamic>[],
    'cursor': 0,
    'has_more': false,
  };

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
    'transcripts': [
      {
        'id': 'transcript-server',
        'recording_id': 'recording-server',
        'content': 'Bonjour à tous.',
        'language': 'fr',
        'segments': [
          {
            'start_ms': 0,
            'end_ms': 1400,
            'text': 'Bonjour à tous.',
            'words': [
              {'start_ms': 0, 'end_ms': 500, 'text': 'Bonjour'},
              {'start_ms': 500, 'end_ms': 760, 'text': 'à'},
              {'start_ms': 760, 'end_ms': 1400, 'text': 'tous.'},
            ],
          },
        ],
        'sync_version': 42,
      },
    ],
    'summaries': [
      {
        'id': 'summary-server',
        'chapter_id': 'chapter-server',
        'recording_id': 'recording-server',
        'generation_id': 'generation-server',
        'content_md': '# Résumé cumulatif',
        'structured_content': {'session_count': 2},
        'status': 'approved',
        'sync_version': 43,
      },
    ],
    'exercises': [
      {
        'id': 'exercise-server',
        'chapter_id': 'chapter-server',
        'recording_id': 'recording-server',
        'generation_id': 'generation-server',
        'items': [
          {'prompt': 'Exercice cumulatif'},
        ],
        'status': 'approved',
        'sync_version': 44,
      },
    ],
    'quizzes': [
      {
        'id': 'quiz-server',
        'chapter_id': 'chapter-server',
        'recording_id': 'recording-server',
        'generation_id': 'generation-server',
        'questions': [
          {'prompt': 'Question cumulative'},
        ],
        'status': 'approved',
        'sync_version': 45,
      },
    ],
    'cursor': 42,
  };

  @override
  Future<List<Map<String, dynamic>>> listQuizAttempts(String quizId) async =>
      const [];
}
