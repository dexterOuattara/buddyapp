/// Central configuration for the mobile app.
class Config {
  /// Base URL of the BuddyWize backend.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:7878/api',
  );

  static const int chunkSizeBytes = 256 * 1024; // 256 KB upload chunks
  static const Duration syncPollInterval = Duration(seconds: 45);
}
