import 'package:buddywize/core/app_theme.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/features/agenda/agenda_screen.dart';
import 'package:buddywize/providers.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpAgenda(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: BuddyTheme.light,
          home: const Scaffold(body: AgendaScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an event for today and opens the add sheet', (
    tester,
  ) async {
    final now = DateTime.now();
    final startsAt = DateTime(now.year, now.month, now.day, 10, 30);
    await db
        .into(db.agendaItems)
        .insert(
          AgendaItemsCompanion.insert(
            clientUuid: 'agenda-widget-test',
            title: 'Mathématiques',
            subject: const Value('Algèbre linéaire'),
            location: const Value('Salle 204'),
            startsAt: Value(startsAt),
            endsAt: Value(startsAt.add(const Duration(hours: 1, minutes: 30))),
          ),
        );

    await pumpAgenda(tester);

    expect(find.text('Mathématiques'), findsOneWidget);
    expect(find.text('Algèbre linéaire'), findsOneWidget);
    expect(find.text('Salle 204'), findsOneWidget);

    await tester.tap(find.byTooltip("Ajouter à l’agenda"));
    await tester.pumpAndSettle();

    expect(find.text('Programmer un cours'), findsOneWidget);
    expect(find.text('Planifier une révision'), findsOneWidget);
    expect(find.text('Ajouter un rappel'), findsOneWidget);
    expect(find.text('Importer iCal'), findsOneWidget);

    // Let Drift's stream-query cleanup timer run inside the fake clock.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
