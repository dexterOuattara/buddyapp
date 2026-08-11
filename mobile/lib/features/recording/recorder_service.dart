import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers.dart';

/// Speech-first capture profile shared by every BuddyWize recording.
///
/// Keep every value explicit: the `record` package defaults to 128 kbps,
/// 44.1 kHz stereo, which materially increases mobile data and API memory use.
const speechRecordingConfig = RecordConfig(
  encoder: AudioEncoder.aacLc,
  bitRate: 48000,
  sampleRate: 16000,
  numChannels: 1,
);

/// Captures audio and registers the recording locally so it can be uploaded
/// opportunistically by the sync engine.
class RecorderService {
  RecorderService(this._db);

  final AppDatabase _db;
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  String? _activePath;
  String? _activeChapterUuid;
  DateTime? _startedAt;

  bool get isRecording => _activePath != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Start recording inside a chapter. Works fully offline.
  Future<void> start({required String chapterClientUuid}) async {
    if (isRecording) return;
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, 'recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    final clientUuid = _uuid.v4();
    final path = p.join(recordingsDir.path, '$clientUuid.m4a');

    await _recorder.start(speechRecordingConfig, path: path);

    _activePath = path;
    _activeChapterUuid = chapterClientUuid;
    _startedAt = DateTime.now();
  }

  /// Stop and atomically persist a recording before any upload starts.
  Future<Recording?> stop() async {
    if (!isRecording) return null;
    final path = await _recorder.stop();
    final duration = DateTime.now().difference(_startedAt!).inSeconds;

    try {
      return await _db
          .into(_db.recordings)
          .insertReturning(
            RecordingsCompanion.insert(
              clientUuid: _uuid.v4(),
              chapterClientUuid: _activeChapterUuid!,
              localPath: path ?? _activePath!,
              fileName: Value(p.basename(path ?? _activePath!)),
              durationSecs: Value(duration),
              status: const Value('pending_sync'),
              pipelineStage: const Value('saved_local'),
              progressPercent: const Value(1),
              statusMessage: const Value('Sauvegardé sur cet appareil'),
              retryable: const Value(true),
              lastProgressAt: Value(DateTime.now()),
            ),
          );
    } finally {
      _activePath = null;
      _activeChapterUuid = null;
      _startedAt = null;
    }
  }

  Future<void> dispose() => _recorder.dispose();
}

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecorderService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});
