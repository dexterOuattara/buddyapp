import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../../sync/sync_engine.dart';
import '../recording/recorder_service.dart';
import '../recording/recording_player_screen.dart';
import '../study/study_screen.dart';

class CourseRecordingScreen extends ConsumerStatefulWidget {
  const CourseRecordingScreen({
    super.key,
    required this.chapter,
    required this.courseTitle,
  });

  final Chapter chapter;
  final String courseTitle;

  @override
  ConsumerState<CourseRecordingScreen> createState() =>
      _CourseRecordingScreenState();
}

class _CourseRecordingScreenState extends ConsumerState<CourseRecordingScreen> {
  bool _recording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final recorder = ref.read(recorderServiceProvider);
    if (!_recording) {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Autorisez le microphone pour enregistrer.'),
            ),
          );
        }
        return;
      }
      await recorder.start(chapterClientUuid: widget.chapter.clientUuid);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });
      if (mounted) setState(() => _recording = true);
      return;
    }

    await recorder.stop();
    _timer?.cancel();
    if (mounted) setState(() => _recording = false);
    final db = ref.read(databaseProvider);
    final recording =
        await (db.select(db.recordings)
              ..where(
                (r) => r.chapterClientUuid.equals(widget.chapter.clientUuid),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (recording == null || !mounted) return;
    unawaited(ref.read(syncEngineProvider).sync());
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CourseProcessingScreen(
          recordingId: recording.id,
          chapter: widget.chapter,
          courseTitle: widget.courseTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: !_recording,
      child: Scaffold(
        appBar: AppBar(title: const Text('Enregistrer un cours')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.courseTitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.chapter.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _recording ? 154 : 138,
                    height: _recording ? 154 : 138,
                    decoration: BoxDecoration(
                      color: _recording
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      color: _recording ? AppColors.error : AppColors.primary,
                      size: 68,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _recording ? '$minutes:$seconds' : 'Prêt à enregistrer',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _recording
                      ? 'L’enregistrement reste disponible même sans connexion.'
                      : 'Le résumé, les fiches et le quiz seront créés après la synchronisation.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _recording
                        ? AppColors.error
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _toggle,
                  icon: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  ),
                  label: Text(
                    _recording
                        ? 'Terminer l’enregistrement'
                        : 'Démarrer l’enregistrement',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CourseProcessingScreen extends ConsumerWidget {
  const CourseProcessingScreen({
    super.key,
    required this.recordingId,
    required this.chapter,
    required this.courseTitle,
  });

  final int recordingId;
  final Chapter chapter;
  final String courseTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final phase = ref.watch(syncPhaseProvider).value ?? SyncPhase.idle;
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<Recording?>(
        stream: (db.select(
          db.recordings,
        )..where((r) => r.id.equals(recordingId))).watchSingleOrNull(),
        builder: (context, snapshot) {
          final recording = snapshot.data;
          if (recording == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<int>(
            future: _fileLength(recording.localPath),
            builder: (context, lengthSnapshot) {
              final fileLength = lengthSnapshot.data ?? 0;
              final uploadProgress = fileLength == 0
                  ? 0.0
                  : (recording.uploadedBytes / fileLength).clamp(0.0, 1.0);
              final uploaded = const {
                'synced',
                'processing',
                'ready',
              }.contains(recording.status);
              final ready = recording.status == 'ready';
              final failed = recording.status == 'failed';
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: ready
                            ? context.statusColors.successContainer
                            : AppColors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ready ? Icons.check_rounded : Icons.graphic_eq_rounded,
                        size: 48,
                        color: ready
                            ? context.statusColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    ready ? 'Cours prêt' : 'Cours enregistré',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RecordingSummaryCard(
                    courseTitle: courseTitle,
                    chapterTitle: chapter.title,
                    durationSeconds: recording.durationSecs ?? 0,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    ready ? 'Traitement terminé' : 'Traitement en cours',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProcessingStep(
                    number: 1,
                    title: 'Sauvegarde sur cet appareil',
                    subtitle: 'Terminé',
                    state: _StepState.done,
                  ),
                  _ProcessingStep(
                    number: 2,
                    title: 'Envoi de l’enregistrement',
                    subtitle: uploaded
                        ? 'Terminé'
                        : recording.status == 'uploading'
                        ? '${(uploadProgress * 100).round()} %'
                        : 'En attente de connexion',
                    progress: recording.status == 'uploading'
                        ? uploadProgress
                        : null,
                    state: failed
                        ? _StepState.failed
                        : uploaded
                        ? _StepState.done
                        : recording.status == 'uploading'
                        ? _StepState.active
                        : _StepState.pending,
                  ),
                  _ProcessingStep(
                    number: 3,
                    title: 'Création du résumé et du quiz',
                    subtitle: ready
                        ? 'Terminé'
                        : failed
                        ? 'Une erreur est survenue'
                        : recording.status == 'processing'
                        ? 'Analyse en cours…'
                        : 'En attente',
                    state: failed
                        ? _StepState.failed
                        : ready
                        ? _StepState.done
                        : recording.status == 'processing'
                        ? _StepState.active
                        : _StepState.pending,
                  ),
                  const SizedBox(height: 18),
                  if (phase == SyncPhase.offline ||
                      recording.status == 'pending_sync')
                    _OfflineNotice(
                      text:
                          'Vous pouvez fermer l’application. Le traitement reprendra automatiquement dès que la connexion sera disponible.',
                    )
                  else if (failed)
                    _OfflineNotice(
                      error: true,
                      text:
                          'Le traitement a échoué. Relancez la synchronisation pour réessayer.',
                    ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: ready
                        ? () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ChapterStudyView(
                                chapter: chapter,
                                courseTitle: courseTitle,
                              ),
                            ),
                          )
                        : () => ref.read(syncEngineProvider).sync(force: true),
                    child: Text(
                      ready ? 'Voir le résumé' : 'Synchroniser maintenant',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecordingPlayerScreen(
                          recording: recording,
                          chapterTitle: chapter.title,
                          courseTitle: courseTitle,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Réécouter l’enregistrement'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retour au chapitre'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

Future<int> _fileLength(String path) async {
  final file = File(path);
  return await file.exists() ? file.length() : 0;
}

class _RecordingSummaryCard extends StatelessWidget {
  const _RecordingSummaryCard({
    required this.courseTitle,
    required this.chapterTitle,
    required this.durationSeconds,
  });

  final String courseTitle;
  final String chapterTitle;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$courseTitle · $chapterTitle',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 17,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Durée ${_duration(durationSeconds)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, active, pending, failed }

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.progress,
  });

  final int number;
  final String title;
  final String subtitle;
  final _StepState state;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.secondary,
      _StepState.failed => AppColors.error,
      _StepState.pending => AppColors.warning,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: state == _StepState.done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : state == _StepState.failed
                ? const Icon(Icons.close_rounded, color: Colors.white, size: 17)
                : Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.secondary,
                    backgroundColor: AppColors.secondary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.cloud_outlined,
            color: error ? AppColors.error : AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}
