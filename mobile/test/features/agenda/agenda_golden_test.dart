import 'package:buddywize/core/app_theme.dart';
import 'package:buddywize/db/app_database.dart';
import 'package:buddywize/features/agenda/agenda_detail_screen.dart';
import 'package:buddywize/features/agenda/agenda_editor_screen.dart';
import 'package:buddywize/features/agenda/agenda_screen.dart';
import 'package:buddywize/features/agenda/agenda_success_screen.dart';
import 'package:buddywize/providers.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const goldenSize = Size(390, 844);
  final fixedDate = DateTime(2026, 8, 10, 10, 30);
  late AppDatabase db;
  late AgendaItem item;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.agendaItems)
        .insert(
          AgendaItemsCompanion.insert(
            clientUuid: '00000000-0000-4000-8000-000000000001',
            title: 'Mathématiques',
            kind: const Value('course'),
            subject: const Value('Algèbre linéaire'),
            location: const Value('Salle 204'),
            notes: const Value('Apporter le manuel'),
            startsAt: Value(fixedDate),
            endsAt: Value(fixedDate.add(const Duration(minutes: 90))),
            recurrence: const Value('weekly'),
            recurrenceUntil: Value(DateTime(2026, 12, 15)),
            reminderMinutes: const Value(10),
            chapterClientUuid: const Value(
              '00000000-0000-4000-8000-000000000002',
            ),
          ),
        );
    item = await db.select(db.agendaItems).getSingle();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(goldenSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuddyTheme.light,
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cleanUpWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.binding.setSurfaceSize(null);
  }

  Widget agendaFrame() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon agenda'),
        actions: const [
          Icon(Icons.cloud_done, color: AppColors.success, size: 19),
          SizedBox(width: 5),
          Text(
            'Synchronisé',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: AgendaScreen(
        initialDate: fixedDate,
        referenceDate: DateTime(2026, 8, 9),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_rounded),
            label: 'Enregistrer',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Cours',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  testWidgets('agenda overview', (tester) async {
    await pumpPage(tester, agendaFrame());
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/agenda_1_overview.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('agenda add bottom sheet', (tester) async {
    await pumpPage(tester, agendaFrame());
    await tester.tap(find.byTooltip("Ajouter à l’agenda"));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/agenda_2_add_sheet.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('agenda information form', (tester) async {
    await pumpPage(tester, AgendaEditorScreen(item: item));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/agenda_3_information.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('agenda recurrence form', (tester) async {
    await pumpPage(tester, AgendaEditorScreen(item: item));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/agenda_4_recurrence.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('agenda success', (tester) async {
    await pumpPage(tester, AgendaSuccessScreen(clientUuid: item.clientUuid));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/agenda_5_success.png'),
    );
    await cleanUpWidget(tester);
  });

  testWidgets('agenda details', (tester) async {
    await pumpPage(tester, AgendaDetailScreen(clientUuid: item.clientUuid));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/agenda_6_details.png'),
    );
    await cleanUpWidget(tester);
  });
}
