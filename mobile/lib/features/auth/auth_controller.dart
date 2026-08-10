import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../providers.dart';
import '../../sync/background_sync.dart';
import 'auth_session_store.dart';

/// Manages the authenticated session and trial/subscription state.
class AuthController extends Notifier<bool> {
  @override
  bool build() {
    final api = ref.watch(apiClientProvider);
    unawaited(_restore());
    final sub = api.onSessionCleared.listen((_) => _clearLocalOnly());
    ref.onDispose(sub.cancel);
    return api.isAuthenticated;
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _restore() async {
    if (await AuthSessionStore.restore(_api)) {
      state = true;
      await _registerBackgroundSync();
      unawaited(ref.read(syncEngineProvider).sync());
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
    await AuthSessionStore.persist(_api);
    state = true;
    await _registerBackgroundSync();
    unawaited(ref.read(syncEngineProvider).sync());
  }

  Future<void> logout() async {
    _api.clearSession();
    await AuthSessionStore.clear();
    await _cancelBackgroundSync();
    state = false;
  }

  /// Drops the local session without going through the explicit logout flow.
  /// Triggered when the API client itself detects an unrecoverable auth
  /// failure (e.g. refresh token revoked).
  Future<void> _clearLocalOnly() async {
    await AuthSessionStore.clear();
    await _cancelBackgroundSync();
    state = false;
  }

  Future<void> _registerBackgroundSync() async {
    try {
      await BackgroundSyncScheduler.registerForAuthenticatedUser();
    } catch (_) {
      // Login and local use must keep working even if Android temporarily
      // refuses to schedule background work.
    }
  }

  Future<void> _cancelBackgroundSync() async {
    try {
      await BackgroundSyncScheduler.cancelForSignedOutUser();
    } catch (_) {
      // The worker also exits immediately when it finds no saved session.
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, bool>(
  AuthController.new,
);
