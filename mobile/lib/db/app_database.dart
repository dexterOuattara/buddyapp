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
  TextColumn get notes => text().nullable()();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Summaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get contentMd => text()();
  TextColumn get status => text().withDefault(const Constant('pending_review'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get itemsJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending_review'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
}

class Quizzes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chapterClientUuid => text()();
  TextColumn get questionsJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending_review'))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
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
    Summaries,
    Exercises,
    Quizzes,
    Meta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'buddywize'));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {},
      );
}
