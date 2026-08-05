import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers.dart';

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

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _activePath = path;
    _activeChapterUuid = chapterClientUuid;
    _startedAt = DateTime.now();
  }

  /// Stop and persist a local-only recording row; sync uploads it later.
  Future<void> stop() async {
    if (!isRecording) return;
    final path = await _recorder.stop();
    final duration = DateTime.now().difference(_startedAt!).inSeconds;

    await _db.into(_db.recordings).insert(RecordingsCompanion.insert(
      clientUuid: _uuid.v4(),
      chapterClientUuid: _activeChapterUuid!,
      localPath: path ?? _activePath!,
      fileName: Value(p.basename(path ?? _activePath!)),
      durationSecs: Value(duration),
      status: const Value('pending_sync'),
    ));

    _activePath = null;
    _activeChapterUuid = null;
    _startedAt = null;
  }

  Future<void> dispose() => _recorder.dispose();
}

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecorderService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});
