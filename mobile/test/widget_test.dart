// Smoke test for the BuddyWize mobile app shell.
//
// Verifies that the app boots, picks up the auth state from SharedPreferences,
// and routes the user to the AuthScreen when no session is stored.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/app.dart';
import 'package:buddywize/providers.dart';

void main() {
  testWidgets('App boots into AuthScreen when there is no stored session',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final api = ApiClient();
    expect(api.isAuthenticated, isFalse);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
        ],
        child: const BuddyWizeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byIcon(Icons.school), findsOneWidget);
  });
}
