import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Local source of truth. Every row carries a `clientUuid` (generated on the
/// device) plus a `pendingSync` flag so the sync engine knows what to push.

class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get serverId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Lessons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get serverId => text().nullable()();
  TextColumn get courseClientUuid => text()();
  TextColumn get title => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get serverId => text().nullable()();
  TextColumn get lessonClientUuid => text()();
  TextColumn get title => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class AgendaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get serverId => text().nullable()();
  TextColumn get title => text()();

  /// course | revision | reminder
  TextColumn get kind => text().withDefault(const Constant('course'))();
  TextColumn get subject => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();

  /// none | weekly
  TextColumn get recurrence => text().withDefault(const Constant('none'))();
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  IntColumn get reminderMinutes => integer().nullable()();
  TextColumn get chapterClientUuid => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Recordings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get localPath => text()();
  TextColumn get fileName => text().nullable()();
  IntColumn get durationSecs => integer().nullable()();

  /// local_only | pending_sync | uploading | synced | processing | ready | failed
  TextColumn get status => text().withDefault(const Constant('local_only'))();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get serverRecordingId => text().nullable()();
  TextColumn get pipelineStage =>
      text().withDefault(const Constant('saved_local'))();
  IntColumn get progressPercent => integer().withDefault(const Constant(0))();
  IntColumn get stageCurrent => integer().nullable()();
  IntColumn get stageTotal => integer().nullable()();
  TextColumn get statusMessage => text().nullable()();
  BoolColumn get retryable => boolean().withDefault(const Constant(true))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get errorCode => text().nullable()();
  // Nullable locally so SQLite can add the columns to an existing database.
  // The server always fills them once remote processing begins.
  DateTimeColumn get stageStartedAt => dateTime().nullable()();
  DateTimeColumn get lastProgressAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Full transcript plus sentence-level timecodes downloaded after processing.
/// It is kept locally so text and synchronized playback work without a network.
class Transcripts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().unique()();
  TextColumn get recordingServerId => text()();
  TextColumn get recordingClientUuid => text().unique()();
  TextColumn get content => text()();
  TextColumn get language => text().nullable()();
  TextColumn get segmentsJson => text().withDefault(const Constant('[]'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
}

class Summaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get recordingServerId => text().nullable()();
  TextColumn get generationId => text().nullable()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get contentMd => text()();
  TextColumn get structuredJson => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending_review'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get recordingServerId => text().nullable()();
  TextColumn get generationId => text().nullable()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get itemsJson => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending_review'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
}

class Quizzes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().nullable()();
  TextColumn get recordingServerId => text().nullable()();
  TextColumn get generationId => text().nullable()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get questionsJson => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending_review'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
}

/// Quiz results are written locally first, then idempotently pushed by
/// [SyncEngine]. This keeps mastery and course progress available offline.
class QuizAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().unique()();
  TextColumn get serverId => text().nullable()();
  TextColumn get quizServerId => text()();
  TextColumn get chapterClientUuid => text()();
  IntColumn get score => integer()();
  IntColumn get total => integer()();
  TextColumn get answersJson => text()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  DateTimeColumn get takenAt => dateTime().withDefault(currentDateAndTime)();
}

/// Small key-value store for sync cursors + auth tokens.
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Courses,
    Lessons,
    Chapters,
    AgendaItems,
    Recordings,
    Transcripts,
    Summaries,
    Exercises,
    Quizzes,
    QuizAttempts,
    Meta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'buddywize'));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(agendaItems, agendaItems.kind);
        await m.addColumn(agendaItems, agendaItems.subject);
        await m.addColumn(agendaItems, agendaItems.location);
        await m.addColumn(agendaItems, agendaItems.recurrence);
        await m.addColumn(agendaItems, agendaItems.recurrenceUntil);
        await m.addColumn(agendaItems, agendaItems.reminderMinutes);
        await m.addColumn(agendaItems, agendaItems.chapterClientUuid);
      }
      if (from < 3) {
        await m.addColumn(summaries, summaries.serverId);
        await m.addColumn(summaries, summaries.recordingServerId);
        await m.addColumn(summaries, summaries.structuredJson);
        await m.addColumn(exercises, exercises.serverId);
        await m.addColumn(exercises, exercises.recordingServerId);
        await m.addColumn(quizzes, quizzes.serverId);
        await m.addColumn(quizzes, quizzes.recordingServerId);
        await m.createTable(quizAttempts);
        // Re-fetch study rows once so databases created before v3 receive
        // the server ids required for idempotent quiz-attempt sync.
        await customStatement("DELETE FROM meta WHERE key = 'study'");
      }
      if (from < 4) {
        await m.createTable(transcripts);
        // Fetch the newly exposed transcript feed even if study content was
        // already synchronized by an older app version.
        await customStatement("DELETE FROM meta WHERE key = 'study'");
      }
      if (from < 5) {
        await m.addColumn(summaries, summaries.generationId);
        await m.addColumn(exercises, exercises.generationId);
        await m.addColumn(quizzes, quizzes.generationId);
        // Reload study packs so their shared generation ids are available for
        // switching between historical cumulative versions.
        await customStatement("DELETE FROM meta WHERE key = 'study'");
      }
      if (from < 6) {
        // SQLite can persist earlier ALTER TABLE statements when a later one
        // fails on some Android versions. Inspect each name so a migration
        // interrupted halfway remains safely resumable.
        final tableInfo = await m.database
            .customSelect("PRAGMA table_info('recordings')")
            .get();
        final existingColumns = tableInfo
            .map((row) => row.read<String>('name'))
            .toSet();
        Future<void> addRecordingColumn(
          String name,
          GeneratedColumn<Object> column,
        ) async {
          if (existingColumns.add(name)) {
            await m.addColumn(recordings, column);
          }
        }

        await addRecordingColumn('pipeline_stage', recordings.pipelineStage);
        await addRecordingColumn(
          'progress_percent',
          recordings.progressPercent,
        );
        await addRecordingColumn('stage_current', recordings.stageCurrent);
        await addRecordingColumn('stage_total', recordings.stageTotal);
        await addRecordingColumn('status_message', recordings.statusMessage);
        await addRecordingColumn('retryable', recordings.retryable);
        await addRecordingColumn('attempt_count', recordings.attemptCount);
        await addRecordingColumn('next_retry_at', recordings.nextRetryAt);
        await addRecordingColumn('error_code', recordings.errorCode);
        await addRecordingColumn('stage_started_at', recordings.stageStartedAt);
        await addRecordingColumn('last_progress_at', recordings.lastProgressAt);
        await customStatement(
          "UPDATE recordings SET "
          "pipeline_stage = CASE status "
          "WHEN 'ready' THEN 'ready' "
          "WHEN 'failed' THEN 'failed' "
          "WHEN 'processing' THEN 'queued' "
          "WHEN 'uploading' THEN 'uploading' "
          "ELSE 'saved_local' END, "
          "progress_percent = CASE status "
          "WHEN 'ready' THEN 100 "
          "WHEN 'processing' THEN 45 "
          "WHEN 'synced' THEN 40 ELSE 0 END",
        );
        // Pull the richer server-side pipeline state for existing recordings.
        await customStatement("DELETE FROM meta WHERE key = 'recordings'");
      }
    },
  );
}
