import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../core/agenda_item.dart';
import '../core/config.dart';

/// Thin REST client over the Swagger-documented backend API.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Optional injection point for tests. Use `MockClient` from `package:http/testing`.
  final http.Client _client;

  String? accessToken;
  String? refreshToken;

  /// True when we hold tokens (i.e. the user is authenticated).
  bool get isAuthenticated => accessToken != null;

  /// Emits whenever the session is dropped (e.g. refresh failed). The auth
  /// controller subscribes to this so the UI can route back to the login
  /// screen without polling.
  final _sessionCleared = StreamController<void>.broadcast();
  Stream<void> get onSessionCleared => _sessionCleared.stream;

  /// Coalesces concurrent refresh attempts so a burst of 401s triggers a
  /// single `/auth/refresh` call instead of N.
  Future<void>? _refreshing;

  Uri _u(String path, [Map<String, String>? query]) {
    final cleaned = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '${Config.apiBaseUrl}$cleaned',
    ).replace(queryParameters: (query == null || query.isEmpty) ? null : query);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  Map<String, String> get _authHeaders => {
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  // -------------------------------------------------------------------- auth

  Future<Map<String, dynamic>> register(String email, String password) =>
      _post('auth/register', {'email': email, 'password': password});

  Future<Map<String, dynamic>> login(String email, String password) =>
      _post('auth/login', {'email': email, 'password': password});

  Future<Map<String, dynamic>> me() => _get('auth/me');

  Future<void> refreshSession() async {
    if (refreshToken == null) throw const ApiAuthException();
    final res = await _post('auth/refresh', {'refresh_token': refreshToken});
    _applyTokens(res);
  }

  void applyAuthResponse(Map<String, dynamic> body) => _applyTokens(body);

  void _applyTokens(Map<String, dynamic> body) {
    accessToken = body['access_token'] as String?;
    refreshToken = body['refresh_token'] as String?;
  }

  // ------------------------------------------------------------------ agenda

  Future<Map<String, dynamic>> listAgenda({int? since}) =>
      _get('agenda', since == null ? null : {'since': '$since'});

  // ------------------------------------------------------------------ courses

  Future<Map<String, dynamic>> listCourses({int? since}) =>
      _get('courses', since == null ? null : {'since': '$since'});
  Future<Map<String, dynamic>> listLessons({int? since}) =>
      _get('lessons', since == null ? null : {'since': '$since'});
  Future<Map<String, dynamic>> listChapters({int? since}) =>
      _get('chapters', since == null ? null : {'since': '$since'});

  Future<Map<String, dynamic>> upsertCourse(Map<String, dynamic> body) =>
      _post('courses', body);
  Future<Map<String, dynamic>> upsertLesson(Map<String, dynamic> body) =>
      _post('lessons', body);
  Future<Map<String, dynamic>> upsertChapter(Map<String, dynamic> body) =>
      _post('chapters', body);

  // --------------------------------------------------------------- recordings

  Future<Map<String, dynamic>> listRecordings({int? since}) =>
      _get('recordings', since == null ? null : {'since': '$since'});

  Future<Map<String, dynamic>> createUpload(Map<String, dynamic> body) =>
      _post('recordings/uploads', body);

  Future<Map<String, dynamic>> uploadChunk(
    String uploadId,
    int offset,
    List<int> bytes,
  ) async {
    final uri = _u('recordings/uploads/$uploadId/chunk', {'offset': '$offset'});
    return _withRefresh(
      () => _client.put(uri, headers: _authHeaders, body: bytes),
      timeout: const Duration(seconds: 60),
    );
  }

  Future<Map<String, dynamic>> completeUpload(String uploadId) =>
      _post('recordings/uploads/$uploadId/complete', const {});

  Future<Map<String, dynamic>> reprocessRecording(String recordingId) =>
      _post('recordings/$recordingId/reprocess', const {});

  // -------------------------------------------------------------------- study

  Future<Map<String, dynamic>> listStudy({int? since}) =>
      _get('study', since == null ? null : {'since': '$since'});

  Future<Map<String, dynamic>> recordQuizAttempt(
    String quizId,
    Map<String, dynamic> body,
  ) => _post('quizzes/$quizId/attempts', body);

  Future<List<Map<String, dynamic>>> listQuizAttempts(String quizId) async {
    final response = await _withRefreshRaw(
      () => _client.get(_u('quizzes/$quizId/attempts'), headers: _headers),
    );
    return _decodeList(response).cast<Map<String, dynamic>>();
  }

  // ----------------------------------------------------------------- agenda

  /// Send an agenda photo to the server for OCR + structuring.
  /// Returns the parsed drafts for the confirmation screen.
  Future<List<AgendaItemDraft>> parseAgendaImage(List<int> jpegBytes) async {
    // Goes through _withRefreshRaw so a 401 transparently refreshes
    // the access token and retries — same pattern every other call uses.
    final resp = await _withRefreshRaw(() async {
      final req = http.MultipartRequest('POST', _u('agenda/parse'))
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            jpegBytes,
            filename: 'agenda.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }, timeout: const Duration(minutes: 2));
    final list = _decodeList(resp);
    return list
        .cast<Map<String, dynamic>>()
        .map(AgendaItemDraft.fromJson)
        .toList(growable: false);
  }

  /// Import agenda items from an iCal text blob.
  /// POST a JSON body and return the raw response (no auto-decode).
  /// Used by endpoints whose body is a JSON array (agenda/ical).
  Future<http.Response> _postRaw(String path, Map<String, dynamic> body) =>
      _withRefreshRaw(
        () => _client.post(_u(path), headers: _headers, body: jsonEncode(body)),
      );

  Future<List<AgendaItemDraft>> importIcalText(String icsText) async {
    final resp = await _postRaw('agenda/ical', {'text': icsText});
    final list = _decodeList(resp);
    return list
        .cast<Map<String, dynamic>>()
        .map(AgendaItemDraft.fromJson)
        .toList(growable: false);
  }

  /// Import agenda items from an iCal URL (server fetches it).
  Future<List<AgendaItemDraft>> importIcalUrl(String url) async {
    final resp = await _postRaw('agenda/ical', {'url': url});
    final list = _decodeList(resp);
    return list
        .cast<Map<String, dynamic>>()
        .map(AgendaItemDraft.fromJson)
        .toList(growable: false);
  }

  /// Upsert one confirmed agenda item into the user's agenda.
  Future<Map<String, dynamic>> upsertAgenda(Map<String, dynamic> body) =>
      _post('agenda', body);

  // --------------------------------------------------------------------- sync

  Future<Map<String, dynamic>> syncStatus({int? since}) =>
      _get('sync/status', since == null ? null : {'since': '$since'});

  // ------------------------------------------------------------------ helpers

  /// Centralizes the 401 → refresh → retry-once flow used by every request.
  ///
  /// On a 401 the client calls `/auth/refresh` exactly once, retries the
  /// original request, and only then surfaces the failure to the caller.
  /// If the refresh itself fails (or there is no refresh token) it throws
  /// [ApiAuthException] so the auth controller can clear the local session.
  /// Returns the raw `http.Response` so callers that need byte-level access
  /// (e.g. multipart endpoints that must stream the body back) don't have
  /// to re-do the decode.
  Future<http.Response> _withRefreshRaw(
    Future<http.Response> Function() send, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final first = await send().timeout(timeout);
    if (first.statusCode != 401) return first;

    await _ensureRefresh();
    final retried = await send().timeout(timeout);
    if (retried.statusCode == 401) {
      clearSession();
      throw const ApiAuthException();
    }
    if (retried.statusCode >= 400) {
      throw ApiException(retried.statusCode, retried.body);
    }
    return retried;
  }

  /// Same as [_withRefreshRaw] but decodes the response body. Use this
  /// for JSON endpoints that don't need streaming.
  Future<Map<String, dynamic>> _withRefresh(
    Future<http.Response> Function() send, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final first = await send().timeout(timeout);
    if (first.statusCode != 401) return _decode(first);

    await _ensureRefresh();
    final retried = await send().timeout(timeout);
    if (retried.statusCode == 401) {
      clearSession();
      throw const ApiAuthException();
    }
    return _decode(retried);
  }

  Future<void> _ensureRefresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    if (refreshToken == null) throw const ApiAuthException();
    try {
      final res = await _client
          .post(
            _u('auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        clearSession();
        throw const ApiAuthException();
      }
      _applyTokens(_decode(res));
    } on ApiException {
      clearSession();
      rethrow;
    }
  }

  /// Drops the local session. Public so the auth controller can call it
  /// after a failed refresh.
  void clearSession() {
    final hadSession = accessToken != null || refreshToken != null;
    accessToken = null;
    refreshToken = null;
    if (hadSession) _sessionCleared.add(null);
  }

  /// Releases the broadcast stream. Call from app shutdown if needed.
  void dispose() {
    _sessionCleared.close();
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) {
    return _withRefresh(() => _client.get(_u(path, query), headers: _headers));
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) {
    return _withRefresh(
      () => _client.post(_u(path), headers: _headers, body: jsonEncode(body)),
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode == 401) throw const ApiAuthException();
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  /// Decode a JSON array response (used by the agenda endpoints).
  List<dynamic> _decodeList(http.Response res) {
    if (res.statusCode == 401) throw const ApiAuthException();
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    if (res.body.isEmpty) return const [];
    final decoded = jsonDecode(res.body);
    return decoded is List ? decoded : const [];
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'API $statusCode: $body';
}

class ApiAuthException implements Exception {
  const ApiAuthException();
  @override
  String toString() => 'Authentication required';
}
