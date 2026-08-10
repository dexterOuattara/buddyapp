// Unit tests for the ApiClient 401 → refresh → retry flow.
//
// These exercise the request helper directly. Each test installs a fake
// `http.Client` so no real network is involved.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buddywize/api/api_client.dart';

http.Client _fakeClient(Future<http.Response> Function(http.Request) handler) {
  return MockClient((request) async => handler(request));
}

void main() {
  group('ApiClient _withRefresh', () {
    test('returns the response normally on 200', () async {
      final client = _fakeClient((req) async => http.Response('{"ok":1}', 200));
      final api = ApiClient(client: client);
      final body = await api.listCourses();
      expect(body['ok'], 1);
    });

    test('refreshes once and retries on 401', () async {
      var attempts = 0;
      var refreshes = 0;
      final client = _fakeClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshes += 1;
          return http.Response(
            jsonEncode({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }),
            200,
          );
        }
        attempts += 1;
        if (attempts == 1) return http.Response('err', 401);
        return http.Response('{"ok":2}', 200);
      });

      final api = ApiClient(client: client);
      api.accessToken = 'old-access';
      api.refreshToken = 'old-refresh';

      final body = await api.listCourses();
      expect(body['ok'], 2);
      expect(api.accessToken, 'new-access');
      expect(api.refreshToken, 'new-refresh');
      expect(refreshes, 1);
    });

    test('coalesces a burst of 401s into a single refresh', () async {
      var refreshes = 0;
      late ApiClient api;
      final client = _fakeClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshes += 1;
          await Future.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }),
            200,
          );
        }
        if (req.url.path.endsWith('/courses') &&
            api.accessToken == 'old-access') {
          return http.Response('err', 401);
        }
        return http.Response('{"ok":true}', 200);
      });

      api = ApiClient(client: client);
      api.accessToken = 'old-access';
      api.refreshToken = 'old-refresh';

      await Future.wait([api.listCourses(), api.listLessons()]);
      expect(refreshes, 1);
    });

    test('clears the session and throws when refresh fails', () async {
      final client = _fakeClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response('expired', 401);
        }
        return http.Response('err', 401);
      });

      final api = ApiClient(client: client);
      api.accessToken = 'old-access';
      api.refreshToken = 'old-refresh';

      await expectLater(
        () => api.listCourses(),
        throwsA(isA<ApiAuthException>()),
      );
      // The onSessionCleared broadcast fires on a microtask scheduled by
      // the broadcast controller; let it drain before asserting on token
      // state (cleared synchronously inside clearSession()).
      await Future<void>.delayed(Duration.zero);
      expect(api.accessToken, isNull);
      expect(api.refreshToken, isNull);
    });

    test('emits onSessionCleared when refresh fails', () async {
      final client = _fakeClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response('expired', 401);
        }
        return http.Response('err', 401);
      });

      final api = ApiClient(client: client);
      api.accessToken = 'old-access';
      api.refreshToken = 'old-refresh';

      final events = <void>[];
      final sub = api.onSessionCleared.listen(events.add);
      await expectLater(
        () => api.listCourses(),
        throwsA(isA<ApiAuthException>()),
      );
      // Drain broadcast delivery before canceling.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, hasLength(1));
    });
  });

  group('quiz attempts', () {
    test('posts the device idempotency key and decodes history arrays', () async {
      Map<String, dynamic>? posted;
      final client = _fakeClient((request) async {
        if (request.method == 'POST') {
          posted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"id":"server-attempt","client_uuid":"client-attempt"}',
            200,
          );
        }
        return http.Response(
          '[{"id":"server-attempt","client_uuid":"client-attempt","score":8,"total":10}]',
          200,
        );
      });
      final api = ApiClient(client: client)..accessToken = 'token';

      final created = await api.recordQuizAttempt('quiz-id', {
        'client_uuid': 'client-attempt',
        'score': 8,
        'total': 10,
        'answers': <dynamic>[],
      });
      final history = await api.listQuizAttempts('quiz-id');

      expect(created['id'], 'server-attempt');
      expect(posted?['client_uuid'], 'client-attempt');
      expect(history.single['score'], 8);
    });
  });
}
