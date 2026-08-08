import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:buddywize/api/api_client.dart';
import 'package:buddywize/api/friendly_error.dart';

void main() {
  group('friendlyApiError', () {
    test('ApiAuthException → "Session expired"', () {
      expect(
        friendlyApiError(const ApiAuthException()),
        'Session expired — please log in again.',
      );
    });

    test('ApiException 401 → "Session expired"', () {
      expect(
        friendlyApiError(ApiException(401, 'unauthorized')),
        'Session expired — please log in again.',
      );
    });

    test('ApiException 403 → "Session expired"', () {
      expect(
        friendlyApiError(ApiException(403, 'forbidden')),
        'Session expired — please log in again.',
      );
    });

    test('ApiException 413 → image-too-large hint', () {
      expect(
        friendlyApiError(ApiException(413, 'too big')),
        'Image is too large. Try a smaller photo.',
      );
    });

    test('ApiException 500 → server-error hint', () {
      expect(
        friendlyApiError(ApiException(500, 'oops')),
        'The server hit an error. Please try again in a moment.',
      );
    });

    test('ApiException 502 → server-error hint', () {
      expect(
        friendlyApiError(ApiException(502, 'bad gateway')),
        'The server hit an error. Please try again in a moment.',
      );
    });

    test('ApiException 400 → generic HTTP message', () {
      expect(
        friendlyApiError(ApiException(400, 'bad request')),
        'Request failed (HTTP 400). Please try again.',
      );
    });

    test('http.ClientException → network hint', () {
      expect(
        friendlyApiError(
          http.ClientException('Connection refused', Uri.parse('http://x/y')),
        ),
        'Could not reach the server. Check your connection.',
      );
    });

    test('arbitrary error is truncated to 120 chars', () {
      final huge = Exception('x' * 500);
      final msg = friendlyApiError(huge);
      expect(msg.length, 120);
      expect(msg.endsWith('...'), true);
    });

    test('short arbitrary error is preserved verbatim', () {
      expect(
        friendlyApiError(StateError('boom')),
        contains('boom'),
      );
    });
  });
}
