import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/sync/sync_engine.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agenda sync pushes the complete offline event contract', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final api = _AgendaApi();
    final engine = SyncEngine(db: db, api: api);
    addTearDown(() async {
      engine.dispose();
      await db.close();
    });

    final startsAt = DateTime(2026, 8, 10, 10, 30);
    await db
        .into(db.agendaItems)
        .insert(
          AgendaItemsCompanion.insert(
            clientUuid: '00000000-0000-4000-8000-000000000001',
            title: 'Mathématiques',
            kind: const Value('course'),
            subject: const Value('Algèbre linéaire'),
            location: const Value('Salle 204'),
            startsAt: Value(startsAt),
            endsAt: Value(startsAt.add(const Duration(minutes: 90))),
            recurrence: const Value('weekly'),
            recurrenceUntil: Value(DateTime(2026, 12, 15)),
            reminderMinutes: const Value(10),
            chapterClientUuid: const Value(
              '00000000-0000-4000-8000-000000000002',
            ),
          ),
        );

    await engine.sync();

    final body = api.agendaBody!;
    expect(body['kind'], 'course');
    expect(body['subject'], 'Algèbre linéaire');
    expect(body['location'], 'Salle 204');
    expect(body['recurrence'], 'weekly');
    expect(body['reminder_minutes'], 10);
    expect(body['starts_at'], endsWith('Z'));
    expect(body['recurrence_until'], endsWith('Z'));
    expect(body['chapter_client_uuid'], '00000000-0000-4000-8000-000000000002');
  });
}

class _AgendaApi extends ApiClient {
  _AgendaApi() {
    accessToken = 'test-token';
  }

  Map<String, dynamic>? agendaBody;

  Map<String, dynamic> get _emptyDelta => const {
    'items': <dynamic>[],
    'cursor': 0,
    'has_more': false,
  };

  @override
  Future<Map<String, dynamic>> upsertAgenda(Map<String, dynamic> body) async {
    agendaBody = body;
    return {'sync_version': 1};
  }

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
