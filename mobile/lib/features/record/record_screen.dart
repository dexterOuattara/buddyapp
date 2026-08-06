import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/app_database.dart';
import '../../providers.dart';
import '../recording/recorder_service.dart';

/// Shows every recording and whether it's safely backed up or still pending.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  bool _recording = false;
  String? _activeChapter;

  Future<void> _toggle() async {
    final recorder = ref.read(recorderServiceProvider);
    if (_recording) {
      await recorder.stop();
      setState(() {
        _recording = false;
        _activeChapter = null;
      });
      // Kick a sync right away so the new recording starts uploading without
      // waiting for the periodic timer (default 45s) or a manual button tap.
      // ignore: unawaited futures
      Future.microtask(() => ref.read(syncEngineProvider).sync());
    } else {
      final chapterUuid = await _pickChapter();
      if (chapterUuid == null) return;
      if (!await recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission needed.')),
          );
        }
        return;
      }
      await recorder.start(chapterClientUuid: chapterUuid);
      setState(() {
        _recording = true;
        _activeChapter = chapterUuid;
      });
    }
  }

  Future<String?> _pickChapter() async {
    final db = ref.read(databaseProvider);
    final chapters = await (db.select(db.chapters)
          ..where((c) => c.deleted.equals(false)))
        .get();
    if (chapters.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create a course and chapter first.'),
          ),
        );
      }
      return null;
    }
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Which chapter is this for?'),
        children: [
          for (final c in chapters)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, c.clientUuid),
              child: Text(c.title),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordings = ref.watch(recordingsStreamProvider).value ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: _recording ? Colors.red.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _recording ? Icons.fiber_manual_record : Icons.mic,
                        color: _recording ? Colors.red : Colors.indigo,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _recording
                              ? 'Recording… tap stop when the lesson ends.'
                              : 'Record a lesson. Works fully offline.',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _recording ? Colors.red : Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _toggle,
                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                    label: Text(_recording ? 'Stop' : 'Start recording'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: recordings.isEmpty
              ? const Center(child: Text('No recordings yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recordings.length,
                  itemBuilder: (context, i) =>
                      _RecordingTile(recording: recordings[i]),
                ),
        ),
      ],
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});
  final Recording recording;

  (IconData, Color, String) get _statusMeta => switch (recording.status) {
        'local_only' ||
        'pending_sync' =>
          (Icons.cloud_upload, Colors.orange, 'Waiting to upload'),
        'uploading' => (Icons.cloud_upload, Colors.blue, 'Uploading…'),
        'synced' => (Icons.cloud_done, Colors.green, 'Uploaded'),
        'processing' => (Icons.psychology, Colors.blue, 'Generating summary…'),
        'ready' => (Icons.check_circle, Colors.green, 'Study material ready'),
        _ => (Icons.error_outline, Colors.red, 'Sync failed'),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _statusMeta;
    return Card(
      child: ListTile(
        leading: Icon(Icons.audiotrack, color: color),
        title: Text(recording.fileName ?? 'Recording'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMd().add_jm().format(recording.createdAt)),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
        trailing: Icon(icon, color: color),
      ),
    );
  }
}
