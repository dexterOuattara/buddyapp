import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../providers.dart';

/// Manages the authenticated session and trial/subscription state.
class AuthController extends Notifier<bool> {
  static const _kAccess = 'auth.access';
  static const _kRefresh = 'auth.refresh';

  @override
  bool build() {
    final api = ref.watch(apiClientProvider);
    _restore();
    final sub = api.onSessionCleared.listen((_) => _clearLocalOnly());
    ref.onDispose(sub.cancel);
    return api.isAuthenticated;
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_kAccess);
    final refresh = prefs.getString(_kRefresh);
    if (access != null) {
      _api.accessToken = access;
      _api.refreshToken = refresh;
      state = true;
    }
  }

  Future<void> register(String email, String password) async {
    final res = await _api.register(email, password);
    await _persist(res);
  }

  Future<void> login(String email, String password) async {
    final res = await _api.login(email, password);
    await _persist(res);
  }

  Future<void> _persist(Map<String, dynamic> res) async {
    _api.applyAuthResponse(res);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, _api.accessToken ?? '');
    await prefs.setString(_kRefresh, _api.refreshToken ?? '');
    state = true;
    // Start syncing right away.
    ref.read(syncEngineProvider).sync();
  }

  Future<void> logout() async {
    _api.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    state = false;
  }

  /// Drops the local session without going through the explicit logout flow.
  /// Triggered when the API client itself detects an unrecoverable auth
  /// failure (e.g. refresh token revoked).
  Future<void> _clearLocalOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    state = false;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, bool>(AuthController.new);
