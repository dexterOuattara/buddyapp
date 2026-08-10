import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/features/agenda/agenda_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgendaItem item({
    required DateTime startsAt,
    String recurrence = 'none',
    DateTime? recurrenceUntil,
    bool deleted = false,
  }) {
    return AgendaItem(
      id: 1,
      clientUuid: 'agenda-1',
      title: 'Mathématiques',
      kind: 'course',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(hours: 1)),
      recurrence: recurrence,
      recurrenceUntil: recurrenceUntil,
      pendingSync: true,
      deleted: deleted,
      syncVersion: 0,
      updatedAt: startsAt,
    );
  }

  group('agendaItemOccursOn', () {
    final monday = DateTime(2026, 8, 10, 10, 30);

    test('one-off item only occurs on its start date', () {
      final value = item(startsAt: monday);
      expect(agendaItemOccursOn(value, DateTime(2026, 8, 10)), isTrue);
      expect(agendaItemOccursOn(value, DateTime(2026, 8, 17)), isFalse);
    });

    test('weekly item repeats on the same weekday through its end date', () {
      final value = item(
        startsAt: monday,
        recurrence: 'weekly',
        recurrenceUntil: DateTime(2026, 8, 31),
      );
      expect(agendaItemOccursOn(value, DateTime(2026, 8, 17)), isTrue);
      expect(agendaItemOccursOn(value, DateTime(2026, 8, 18)), isFalse);
      expect(agendaItemOccursOn(value, DateTime(2026, 9, 7)), isFalse);
    });

    test('deleted items never occur', () {
      expect(
        agendaItemOccursOn(item(startsAt: monday, deleted: true), monday),
        isFalse,
      );
    });
  });
}
