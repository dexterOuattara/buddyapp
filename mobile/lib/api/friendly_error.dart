import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Convert any error from the API client into a short, user-facing
/// message. Auth errors get a specific hint to log in again; everything
/// else falls through to a generic but informative message.
String friendlyApiError(Object error) {
  if (error is ApiAuthException) {
    return 'Session expired — please log in again.';
  }
  if (error is ApiException) {
    final s = error.statusCode;
    if (s == 401 || s == 403) {
      return 'Session expired — please log in again.';
    }
    if (s == 413) {
      return 'Image is too large. Try a smaller photo.';
    }
    if (s >= 500) {
      return 'The server hit an error. Please try again in a moment.';
    }
    return 'Request failed (HTTP $s). Please try again.';
  }
  if (error is http.ClientException) {
    return 'Could not reach the server. Check your connection.';
  }
  // Anything else: surface the raw message but truncate it.
  final s = error.toString();
  return s.length > 120 ? '${s.substring(0, 117)}...' : s;
}
