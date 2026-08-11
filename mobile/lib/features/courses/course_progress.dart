import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';

enum ChapterLearningStatus { notStarted, inProgress, review, completed }

class ChapterMaterialVersion {
  const ChapterMaterialVersion({
    required this.key,
    required this.summary,
    required this.exercise,
    required this.quiz,
    required this.recording,
  });

  final String key;
  final Summary? summary;
  final Exercise? exercise;
  final Quizze? quiz;
  final Recording? recording;

  int get syncVersion => [
    summary?.syncVersion ?? 0,
    exercise?.syncVersion ?? 0,
    quiz?.syncVersion ?? 0,
  ].reduce((current, next) => current > next ? current : next);

  int get sessionCount => _materialSessionCount(summary?.structuredJson);
}

class ChapterProgress {
  const ChapterProgress({
    required this.lesson,
    required this.chapter,
    required this.recordings,
    required this.transcriptsByRecordingClientUuid,
    required this.materialVersions,
    required this.summary,
    required this.exercise,
    required this.quiz,
    required this.latestAttempt,
    required this.status,
    required this.mastery,
    required this.exerciseCount,
    required this.quizCount,
    required this.flashcardCount,
  });

  final Lesson lesson;
  final Chapter chapter;
  final List<Recording> recordings;
  final Map<String, Transcript> transcriptsByRecordingClientUuid;
  final List<ChapterMaterialVersion> materialVersions;
  final Summary? summary;
  final Exercise? exercise;
  final Quizze? quiz;
  final QuizAttempt? latestAttempt;
  final ChapterLearningStatus status;
  final int mastery;
  final int exerciseCount;
  final int quizCount;
  final int flashcardCount;

  bool get hasMaterial => summary != null || exercise != null || quiz != null;
  int get materialVersionCount => materialVersions.length;
  int get materialSessionCount =>
      materialVersions.firstOrNull?.sessionCount ?? 0;

  Transcript? transcriptFor(Recording recording) =>
      transcriptsByRecordingClientUuid[recording.clientUuid];
}

class CourseProgress {
  const CourseProgress({
    required this.course,
    required this.chapters,
    required this.progress,
    required this.mastery,
  });

  final Course course;
  final List<ChapterProgress> chapters;
  final double progress;
  final int mastery;

  int get completedCount =>
      chapters.where((c) => c.status == ChapterLearningStatus.completed).length;

  bool get isCompleted =>
      chapters.isNotEmpty && completedCount == chapters.length;

  ChapterProgress? get currentChapter {
    if (chapters.isEmpty) return null;
    for (final status in const [
      ChapterLearningStatus.inProgress,
      ChapterLearningStatus.review,
      ChapterLearningStatus.notStarted,
    ]) {
      for (final chapter in chapters) {
        if (chapter.status == status) return chapter;
      }
    }
    return chapters.last;
  }
}

class CourseCatalogSnapshot {
  const CourseCatalogSnapshot(this.courses);
  final List<CourseProgress> courses;

  ChapterProgress? chapter(String clientUuid) {
    for (final course in courses) {
      for (final chapter in course.chapters) {
        if (chapter.chapter.clientUuid == clientUuid) return chapter;
      }
    }
    return null;
  }
}

/// Produces one reactive, offline-first read model for all course screens.
/// The custom watch query is invalidated whenever any source table changes,
/// then the small local dataset is aggregated in Dart.
class CourseCatalogRepository {
  CourseCatalogRepository(this.db);

  final AppDatabase db;

  Stream<CourseCatalogSnapshot> watch() {
    return db
        .customSelect(
          'SELECT 1 AS course_catalog_version',
          readsFrom: {
            db.courses,
            db.lessons,
            db.chapters,
            db.recordings,
            db.transcripts,
            db.summaries,
            db.exercises,
            db.quizzes,
            db.quizAttempts,
          },
        )
        .watch()
        .asyncMap((_) => load());
  }

  Future<CourseCatalogSnapshot> load() async {
    final courses =
        await (db.select(db.courses)
              ..where((c) => c.deleted.equals(false))
              ..orderBy([(c) => OrderingTerm.asc(c.title)]))
            .get();
    final lessons =
        await (db.select(db.lessons)
              ..where((l) => l.deleted.equals(false))
              ..orderBy([(l) => OrderingTerm.asc(l.position)]))
            .get();
    final chapters =
        await (db.select(db.chapters)
              ..where((c) => c.deleted.equals(false))
              ..orderBy([(c) => OrderingTerm.asc(c.position)]))
            .get();
    final recordings = await (db.select(
      db.recordings,
    )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();
    final transcripts = await db.select(db.transcripts).get();
    final transcriptsByRecordingClientUuid = {
      for (final transcript in transcripts)
        transcript.recordingClientUuid: transcript,
    };
    final summaries = await db.select(db.summaries).get();
    final exercises = await db.select(db.exercises).get();
    final quizzes = await db.select(db.quizzes).get();
    final attempts = await (db.select(
      db.quizAttempts,
    )..orderBy([(a) => OrderingTerm.desc(a.takenAt)])).get();

    final built = <CourseProgress>[];
    for (final course in courses) {
      final courseLessons = lessons
          .where((lesson) => lesson.courseClientUuid == course.clientUuid)
          .toList();
      final chapterProgress = <ChapterProgress>[];
      for (final lesson in courseLessons) {
        final lessonChapters = chapters
            .where((chapter) => chapter.lessonClientUuid == lesson.clientUuid)
            .toList();
        for (final chapter in lessonChapters) {
          final chapterRecordings = recordings
              .where((r) => r.chapterClientUuid == chapter.clientUuid)
              .toList();
          final materialVersions = _buildMaterialVersions(
            chapterRecordings,
            summaries.where(
              (summary) => summary.chapterClientUuid == chapter.clientUuid,
            ),
            exercises.where(
              (exercise) => exercise.chapterClientUuid == chapter.clientUuid,
            ),
            quizzes.where(
              (quiz) => quiz.chapterClientUuid == chapter.clientUuid,
            ),
          );
          final currentMaterial = materialVersions.firstOrNull;
          final summary = currentMaterial?.summary;
          final exercise = currentMaterial?.exercise;
          final quiz = currentMaterial?.quiz;
          final chapterAttempts = attempts
              .where((a) => a.chapterClientUuid == chapter.clientUuid)
              .toList();
          final latestAttempt = chapterAttempts.isEmpty
              ? null
              : chapterAttempts.first;
          final mastery = latestAttempt == null || latestAttempt.total == 0
              ? 0
              : ((latestAttempt.score / latestAttempt.total) * 100).round();
          final hasActivity =
              chapterRecordings.isNotEmpty ||
              summary != null ||
              exercise != null ||
              quiz != null;
          final status = latestAttempt != null
              ? (mastery >= 70
                    ? ChapterLearningStatus.completed
                    : ChapterLearningStatus.review)
              : (hasActivity
                    ? ChapterLearningStatus.inProgress
                    : ChapterLearningStatus.notStarted);

          chapterProgress.add(
            ChapterProgress(
              lesson: lesson,
              chapter: chapter,
              recordings: chapterRecordings,
              transcriptsByRecordingClientUuid:
                  transcriptsByRecordingClientUuid,
              materialVersions: materialVersions,
              summary: summary,
              exercise: exercise,
              quiz: quiz,
              latestAttempt: latestAttempt,
              status: status,
              mastery: mastery,
              exerciseCount: _jsonListLength(exercise?.itemsJson),
              quizCount: _jsonListLength(quiz?.questionsJson),
              flashcardCount: _flashcardCount(summary?.structuredJson),
            ),
          );
        }
      }

      final completed = chapterProgress
          .where((c) => c.status == ChapterLearningStatus.completed)
          .length;
      final attempted = chapterProgress.where((c) => c.latestAttempt != null);
      final mastery = attempted.isEmpty
          ? 0
          : (attempted.fold<int>(0, (sum, c) => sum + c.mastery) /
                    attempted.length)
                .round();
      built.add(
        CourseProgress(
          course: course,
          chapters: chapterProgress,
          progress: chapterProgress.isEmpty
              ? 0
              : completed / chapterProgress.length,
          mastery: mastery,
        ),
      );
    }

    return CourseCatalogSnapshot(built);
  }
}

List<ChapterMaterialVersion> _buildMaterialVersions(
  List<Recording> recordings,
  Iterable<Summary> summaries,
  Iterable<Exercise> exercises,
  Iterable<Quizze> quizzes,
) {
  final builders = <String, _MaterialVersionBuilder>{};

  for (final summary in summaries) {
    final key = _materialVersionKey(
      generationId: summary.generationId,
      recordingServerId: summary.recordingServerId,
    );
    final builder = builders.putIfAbsent(
      key,
      () => _MaterialVersionBuilder(key),
    );
    if (builder.summary == null ||
        summary.syncVersion >= builder.summary!.syncVersion) {
      builder.summary = summary;
    }
    builder.recordingServerId ??= summary.recordingServerId;
  }
  for (final exercise in exercises) {
    final key = _materialVersionKey(
      generationId: exercise.generationId,
      recordingServerId: exercise.recordingServerId,
    );
    final builder = builders.putIfAbsent(
      key,
      () => _MaterialVersionBuilder(key),
    );
    if (builder.exercise == null ||
        exercise.syncVersion >= builder.exercise!.syncVersion) {
      builder.exercise = exercise;
    }
    builder.recordingServerId ??= exercise.recordingServerId;
  }
  for (final quiz in quizzes) {
    final key = _materialVersionKey(
      generationId: quiz.generationId,
      recordingServerId: quiz.recordingServerId,
    );
    final builder = builders.putIfAbsent(
      key,
      () => _MaterialVersionBuilder(key),
    );
    if (builder.quiz == null || quiz.syncVersion >= builder.quiz!.syncVersion) {
      builder.quiz = quiz;
    }
    builder.recordingServerId ??= quiz.recordingServerId;
  }

  final versions = [
    for (final builder in builders.values)
      ChapterMaterialVersion(
        key: builder.key,
        summary: builder.summary,
        exercise: builder.exercise,
        quiz: builder.quiz,
        recording: recordings
            .where(
              (recording) =>
                  recording.serverRecordingId == builder.recordingServerId,
            )
            .firstOrNull,
      ),
  ]..sort((a, b) => b.syncVersion.compareTo(a.syncVersion));
  return versions;
}

String _materialVersionKey({
  required String? generationId,
  required String? recordingServerId,
}) {
  if (generationId?.isNotEmpty == true) return 'generation:$generationId';
  if (recordingServerId?.isNotEmpty == true) {
    return 'recording:$recordingServerId';
  }
  return 'legacy';
}

class _MaterialVersionBuilder {
  _MaterialVersionBuilder(this.key);

  final String key;
  String? recordingServerId;
  Summary? summary;
  Exercise? exercise;
  Quizze? quiz;
}

int _jsonListLength(String? value) {
  if (value == null) return 0;
  try {
    final decoded = jsonDecode(value);
    return decoded is List ? decoded.length : 0;
  } catch (_) {
    return 0;
  }
}

int _flashcardCount(String? value) {
  if (value == null) return 0;
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) return 0;
    final cards = decoded['flashcards'];
    return cards is List ? cards.length : 0;
  } catch (_) {
    return 0;
  }
}

int _materialSessionCount(String? value) {
  if (value == null) return 1;
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) return 1;
    final count = decoded['session_count'];
    if (count is num && count.toInt() > 0) return count.toInt();
  } catch (_) {
    // Legacy study packs represent a single source session.
  }
  return 1;
}
