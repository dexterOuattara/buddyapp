import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';

/// Persistent session shared by the foreground app and the background worker.
class AuthSessionStore {
  const AuthSessionStore._();

  static const accessKey = 'auth.access';
  static const refreshKey = 'auth.refresh';

  static Future<bool> restore(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(accessKey)?.trim();
    final refresh = prefs.getString(refreshKey)?.trim();
    if (access == null || access.isEmpty) return false;
    api.accessToken = access;
    api.refreshToken = refresh == null || refresh.isEmpty ? null : refresh;
    return true;
  }

  /// Persists refreshed tokens too, not only the initial login response.
  static Future<void> persist(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    final access = api.accessToken;
    if (access == null || access.isEmpty) {
      await clear();
      return;
    }
    await prefs.setString(accessKey, access);
    final refresh = api.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await prefs.remove(refreshKey);
    } else {
      await prefs.setString(refreshKey, refresh);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessKey);
    await prefs.remove(refreshKey);
  }
}
