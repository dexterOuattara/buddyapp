import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/features/courses/course_progress.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CourseCatalogRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CourseCatalogRepository(db);
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(clientUuid: 'course', title: 'Mathématiques'),
        );
    await db
        .into(db.lessons)
        .insert(
          LessonsCompanion.insert(
            clientUuid: 'lesson',
            courseClientUuid: 'course',
            title: 'Algèbre linéaire',
          ),
        );
    for (var i = 1; i <= 3; i++) {
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              clientUuid: 'chapter-$i',
              lessonClientUuid: 'lesson',
              title: 'Chapitre $i',
              position: Value(i),
            ),
          );
    }
  });

  tearDown(() => db.close());

  Future<void> addAttempt({
    required String clientUuid,
    required String chapterUuid,
    required int score,
    required int total,
    DateTime? takenAt,
  }) {
    return db
        .into(db.quizAttempts)
        .insert(
          QuizAttemptsCompanion.insert(
            clientUuid: clientUuid,
            quizServerId: 'quiz-server',
            chapterClientUuid: chapterUuid,
            score: score,
            total: total,
            answersJson: '[]',
            takenAt: Value(takenAt ?? DateTime.now()),
          ),
        );
  }

  test('derives chapter states, course progress and mastery offline', () async {
    await db
        .into(db.recordings)
        .insert(
          RecordingsCompanion.insert(
            clientUuid: 'recording',
            chapterClientUuid: 'chapter-1',
            localPath: '/tmp/recording.m4a',
          ),
        );
    await addAttempt(
      clientUuid: 'attempt-low',
      chapterUuid: 'chapter-2',
      score: 2,
      total: 5,
    );
    await addAttempt(
      clientUuid: 'attempt-high',
      chapterUuid: 'chapter-3',
      score: 5,
      total: 5,
    );

    final course = (await repository.load()).courses.single;

    expect(course.chapters[0].status, ChapterLearningStatus.inProgress);
    expect(course.chapters[1].status, ChapterLearningStatus.review);
    expect(course.chapters[2].status, ChapterLearningStatus.completed);
    expect(course.progress, closeTo(1 / 3, 0.001));
    expect(course.mastery, 70);
    expect(course.currentChapter?.chapter.clientUuid, 'chapter-1');
  });

  test('uses the latest attempt as current chapter mastery', () async {
    await addAttempt(
      clientUuid: 'attempt-old',
      chapterUuid: 'chapter-1',
      score: 5,
      total: 5,
      takenAt: DateTime(2026, 8, 8),
    );
    await addAttempt(
      clientUuid: 'attempt-new',
      chapterUuid: 'chapter-1',
      score: 1,
      total: 5,
      takenAt: DateTime(2026, 8, 9),
    );

    final chapter = (await repository.load()).courses.single.chapters.first;

    expect(chapter.mastery, 20);
    expect(chapter.status, ChapterLearningStatus.review);
  });

  test('associates a transcript with its recording', () async {
    await db
        .into(db.recordings)
        .insert(
          RecordingsCompanion.insert(
            clientUuid: 'recording-with-transcript',
            chapterClientUuid: 'chapter-1',
            localPath: '/tmp/recording-with-transcript.m4a',
            serverRecordingId: const Value('recording-server'),
          ),
        );
    await db
        .into(db.transcripts)
        .insert(
          TranscriptsCompanion.insert(
            serverId: 'transcript-server',
            recordingServerId: 'recording-server',
            recordingClientUuid: 'recording-with-transcript',
            content: 'Transcription conservée.',
          ),
        );

    final chapter = (await repository.load()).courses.single.chapters.first;
    final recording = chapter.recordings.single;

    expect(
      chapter.transcriptFor(recording)?.content,
      'Transcription conservée.',
    );
  });

  test('counts structured flashcards, exercises and quiz questions', () async {
    await db
        .into(db.summaries)
        .insert(
          SummariesCompanion.insert(
            chapterClientUuid: 'chapter-1',
            contentMd: '# Résumé',
            structuredJson: const Value(
              '{"flashcards":[{"front":"A","back":"B"},{"front":"C","back":"D"}]}',
            ),
          ),
        );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            chapterClientUuid: 'chapter-1',
            itemsJson: '[{"prompt":"1"},{"prompt":"2"},{"prompt":"3"}]',
          ),
        );
    await db
        .into(db.quizzes)
        .insert(
          QuizzesCompanion.insert(
            chapterClientUuid: 'chapter-1',
            questionsJson: '[{"prompt":"1"},{"prompt":"2"}]',
          ),
        );

    final chapter = (await repository.load()).courses.single.chapters.first;

    expect(chapter.flashcardCount, 2);
    expect(chapter.exerciseCount, 3);
    expect(chapter.quizCount, 2);
  });

  test(
    'keeps many recordings and groups immutable cumulative material',
    () async {
      for (var index = 1; index <= 2; index++) {
        await db
            .into(db.recordings)
            .insert(
              RecordingsCompanion.insert(
                clientUuid: 'recording-$index',
                chapterClientUuid: 'chapter-1',
                localPath: '/tmp/recording-$index.m4a',
                serverRecordingId: Value('recording-server-$index'),
                createdAt: Value(DateTime(2026, 8, index)),
              ),
            );
        await db
            .into(db.summaries)
            .insert(
              SummariesCompanion.insert(
                serverId: Value('summary-$index'),
                recordingServerId: Value('recording-server-$index'),
                generationId: Value('generation-$index'),
                chapterClientUuid: 'chapter-1',
                contentMd: '# Version $index',
                structuredJson: Value('{"session_count":$index}'),
                syncVersion: Value(index * 10),
              ),
            );
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                serverId: Value('exercise-$index'),
                recordingServerId: Value('recording-server-$index'),
                generationId: Value('generation-$index'),
                chapterClientUuid: 'chapter-1',
                itemsJson: '[{"prompt":"Version $index"}]',
                syncVersion: Value(index * 10 + 1),
              ),
            );
        await db
            .into(db.quizzes)
            .insert(
              QuizzesCompanion.insert(
                serverId: Value('quiz-$index'),
                recordingServerId: Value('recording-server-$index'),
                generationId: Value('generation-$index'),
                chapterClientUuid: 'chapter-1',
                questionsJson: '[{"prompt":"Version $index"}]',
                syncVersion: Value(index * 10 + 2),
              ),
            );
      }

      final chapter = (await repository.load()).courses.single.chapters.first;

      expect(chapter.recordings.map((row) => row.clientUuid), [
        'recording-2',
        'recording-1',
      ]);
      expect(chapter.materialVersionCount, 2);
      expect(chapter.materialSessionCount, 2);
      expect(chapter.summary?.contentMd, '# Version 2');
      expect(
        chapter.materialVersions.first.exercise?.generationId,
        'generation-2',
      );
      expect(chapter.materialVersions.first.quiz?.generationId, 'generation-2');
      expect(chapter.materialVersions.last.summary?.contentMd, '# Version 1');
    },
  );
}
