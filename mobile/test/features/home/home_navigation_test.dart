import 'package:buddywize/core/app_theme.dart';
import 'package:buddywize/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the menu visible and supports toolbar and system back', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<BuddyTabNavigatorState>();
    var canPop = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: BuddyTheme.light,
        home: Scaffold(
          body: BuddyTabNavigator(
            key: navigatorKey,
            active: true,
            onCanPopChanged: (value) => canPop = value,
            root: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Détail')),
                        body: const Center(child: Text('Contenu du détail')),
                      ),
                    ),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Menu principal',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                label: 'Autre onglet',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Détail'), findsOneWidget);
    expect(find.text('Menu principal'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(canPop, isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Menu principal'), findsOneWidget);
    expect(canPop, isFalse);

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Détail'), findsNothing);
    expect(find.text('Menu principal'), findsOneWidget);
  });
}
