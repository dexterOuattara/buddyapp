# BuddyWize Mobile (Flutter)

Offline-first student app: agenda, course/lesson/chapter structure, lesson
recording, and AI-generated study material — all backed by a local SQLite
database (drift) that syncs with the Rust backend when connectivity allows.

## Setup

```bash
flutter pub get
# Generate the drift database code (app_database.g.dart):
dart run build_runner build --delete-conflicting-outputs
```

If platform folders are missing, regenerate them once:

```bash
flutter create --org com.buddywize --project-name buddywize --platforms android,ios .
```

## Run

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:7878/api
```

Use `http://<your-machine-ip>:7878/api` when running on a physical device.

## Permissions (recording)

Android: add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

iOS: add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>BuddyWize records your lessons so it can generate summaries and quizzes.</string>
```

## Architecture map

- `lib/db/app_database.dart` — drift schema: on-device source of truth; every
  row has a `clientUuid` + `pendingSync` flag.
- `lib/sync/sync_engine.dart` — push (dirty rows, chunked/resumable recording
  uploads) + pull (`?since=` delta cursors) phases.
- `lib/api/api_client.dart` — REST client matching the backend OpenAPI spec.
- `lib/features/` — agenda, courses, record, study, account UI.
