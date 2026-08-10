import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'config.dart';

/// Streams connectivity changes so the sync engine can react.
class ConnectivityService {
  ConnectivityService() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      unawaited(_emitConnectivity(results));
    });
  }

  final _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<bool> get isOnline async {
    return checkOnline();
  }

  Future<void> _emitConnectivity(List<ConnectivityResult> results) async {
    final hasSystemNetwork = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final online =
        hasSystemNetwork ||
        (usesLoopbackApi(Config.apiBaseUrl) && await _probeConfiguredApi());
    if (!_controller.isClosed) _controller.add(online);
  }

  /// Connectivity Plus reports network interfaces, not endpoint
  /// reachability. A USB reverse tunnel exposes the development API through
  /// localhost even when Android reports no Wi-Fi/mobile interface, so probe
  /// that endpoint before declaring the app offline.
  static Future<bool> checkOnline({
    Future<List<ConnectivityResult>> Function()? networkCheck,
    Future<bool> Function()? apiProbe,
  }) async {
    final results = await (networkCheck ?? Connectivity().checkConnectivity)();
    if (results.any((result) => result != ConnectivityResult.none)) return true;
    if (!usesLoopbackApi(Config.apiBaseUrl)) return false;
    return (apiProbe ?? _probeConfiguredApi)();
  }

  static bool usesLoopbackApi(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  static Future<bool> _probeConfiguredApi() async {
    final base = Uri.parse(Config.apiBaseUrl);
    final health = base.replace(path: '/health', query: null, fragment: null);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client
          .getUrl(health)
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
