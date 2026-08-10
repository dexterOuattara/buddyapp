import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/features/auth/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'background and foreground isolates share persisted auth tokens',
    () async {
      final first = ApiClient()
        ..accessToken = 'access-1'
        ..refreshToken = 'refresh-1';
      await AuthSessionStore.persist(first);

      final restored = ApiClient();
      expect(await AuthSessionStore.restore(restored), isTrue);
      expect(restored.accessToken, 'access-1');
      expect(restored.refreshToken, 'refresh-1');
    },
  );

  test('clearing tokens disables background authentication', () async {
    final api = ApiClient()..accessToken = 'access-1';
    await AuthSessionStore.persist(api);
    await AuthSessionStore.clear();

    final restored = ApiClient();
    expect(await AuthSessionStore.restore(restored), isFalse);
    expect(restored.isAuthenticated, isFalse);
  });
}
