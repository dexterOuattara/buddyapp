// Unit tests for the sync engine's pull logic.
//
// We focus on the InsertMode.insertOrReplace fix: when the same row is
// pulled back from the server (after being pushed), Drift used to crash
// on the UNIQUE constraint because insertOnConflictUpdate defaulted the
// conflict target to the auto-increment PK. We verify the fix works against
// an in-memory SQLite database.

import 'package:buddywize/db/app_database.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase insertOrReplace for sync pulled rows', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('inserting then re-inserting same clientUuid updates the row',
        () async {
      final firstId = await db.into(db.courses).insert(
            CoursesCompanion.insert(
              clientUuid: 'course-1',
              title: 'Original',
              pendingSync: const Value(true),
            ),
          );
      expect(firstId, isPositive);

      // Server round-trips the row with a serverId populated.
      await db.into(db.courses).insert(
        CoursesCompanion.insert(
          clientUuid: 'course-1',
          serverId: const Value('server-uuid-1'),
          title: 'Original',
          pendingSync: const Value(false),
          syncVersion: const Value(42),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // Only one row remains.
      final rows = await db.select(db.courses).get();
      expect(rows, hasLength(1));

      // The new fields are persisted.
      final row = rows.first;
      expect(row.serverId, 'server-uuid-1');
      expect(row.pendingSync, false);
      expect(row.syncVersion, 42);
      // New auto-increment id was assigned (insertOrReplace deletes + reinserts).
      expect(row.id, isNot(firstId));
    });

    test('different clientUuids coexist (UNIQUE does not collide)',
        () async {
      await db.into(db.courses).insert(CoursesCompanion.insert(
            clientUuid: 'course-a',
            title: 'A',
          ));
      await db.into(db.courses).insert(CoursesCompanion.insert(
            clientUuid: 'course-b',
            title: 'B',
          ));

      final rows = await db.select(db.courses).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.title).toSet(), {'A', 'B'});
    });

    test('lessons / chapters / agenda also use insertOrReplace correctly',
        () async {
      // Lessons.
      final cid = 'course-1';
      await db.into(db.courses).insert(CoursesCompanion.insert(
            clientUuid: cid,
            title: 'C',
          ));
      await db.into(db.lessons).insert(LessonsCompanion.insert(
            clientUuid: 'lesson-1',
            courseClientUuid: cid,
            title: 'L',
          ));
      // Re-pull: same client_uuid, new server id.
      await db.into(db.lessons).insert(
        LessonsCompanion.insert(
          clientUuid: 'lesson-1',
          courseClientUuid: cid,
          serverId: const Value('lesson-server'),
          title: 'L',
          pendingSync: const Value(false),
        ),
        mode: InsertMode.insertOrReplace,
      );
      final lessons = await db.select(db.lessons).get();
      expect(lessons, hasLength(1));
      expect(lessons.first.serverId, 'lesson-server');

      // Chapters.
      await db.into(db.chapters).insert(ChaptersCompanion.insert(
            clientUuid: 'chapter-1',
            lessonClientUuid: 'lesson-1',
            title: 'Ch',
          ));
      await db.into(db.chapters).insert(
        ChaptersCompanion.insert(
          clientUuid: 'chapter-1',
          lessonClientUuid: 'lesson-1',
          serverId: const Value('ch-server'),
          title: 'Ch',
          pendingSync: const Value(false),
        ),
        mode: InsertMode.insertOrReplace,
      );
      final chapters = await db.select(db.chapters).get();
      expect(chapters, hasLength(1));
      expect(chapters.first.serverId, 'ch-server');

      // Agenda.
      await db.into(db.agendaItems).insert(AgendaItemsCompanion.insert(
            clientUuid: 'agenda-1',
            title: 'A1',
          ));
      await db.into(db.agendaItems).insert(
        AgendaItemsCompanion.insert(
          clientUuid: 'agenda-1',
          serverId: const Value('a-server'),
          title: 'A1',
          pendingSync: const Value(false),
        ),
        mode: InsertMode.insertOrReplace,
      );
      final agenda = await db.select(db.agendaItems).get();
      expect(agenda, hasLength(1));
      expect(agenda.first.serverId, 'a-server');
    });

    test('meta table insertOnConflictUpdate works on its primary key (cursor)',
        () async {
      // Meta uses insertOnConflictUpdate with the default (PK = key)
      // target — no special handling needed, this is a regression guard.
      await db.into(db.meta).insertOnConflictUpdate(
        MetaCompanion.insert(key: 'courses', value: '1'),
      );
      await db.into(db.meta).insertOnConflictUpdate(
        MetaCompanion.insert(key: 'courses', value: '5'),
      );
      final row = await (db.select(db.meta)..where((m) => m.key.equals('courses')))
          .getSingle();
      expect(row.value, '5');
    });

    test('INSERT OR REPLACE works exactly as the sync engine does (regression)',
        () async {
      // This mirrors what sync_engine.dart does for every pulled row:
      // first push (no serverId), then pull (serverId set, same clientUuid).
      await db.into(db.courses).insert(
        CoursesCompanion.insert(
          clientUuid: 'course-X',
          title: 'X',
          pendingSync: const Value(true),
        ),
      );

      // No row should have server_id yet.
      var beforePull = await db.select(db.courses).get();
      expect(beforePull.single.serverId, isNull);

      await db.into(db.courses).insert(
        CoursesCompanion.insert(
          clientUuid: 'course-X',
          serverId: const Value('sX'),
          title: 'X',
          pendingSync: const Value(false),
          syncVersion: const Value(1),
        ),
        mode: InsertMode.insertOrReplace,
      );

      final rows = await db.select(db.courses).get();
      expect(rows, hasLength(1), reason: 'must not duplicate the row');
      expect(rows.single.serverId, 'sX');
      expect(rows.single.pendingSync, false);
      expect(rows.single.syncVersion, 1);
    });
  });
}

