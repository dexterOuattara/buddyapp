import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import '../../sync/background_sync.dart';
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

    final recording = await recorder.stop();
    _timer?.cancel();
    if (mounted) setState(() => _recording = false);
    if (recording == null || !mounted) return;
    unawaited(BackgroundSyncScheduler.enqueueWhenOnline());
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

  Future<void> _continueOrRetry(
    BuildContext context,
    WidgetRef ref,
    Recording recording,
  ) async {
    final recordingId = recording.serverRecordingId;
    try {
      if (recording.status == 'failed' && recordingId != null) {
        await ref.read(apiClientProvider).reprocessRecording(recordingId);
        await (ref.read(databaseProvider).update(
          ref.read(databaseProvider).recordings,
        )..where((row) => row.id.equals(recording.id))).write(
          RecordingsCompanion(
            status: const Value('processing'),
            pipelineStage: const Value('queued'),
            progressPercent: Value(
              recording.progressPercent.clamp(40, 100),
            ),
            statusMessage: const Value('Traitement ajouté à la file'),
            retryable: const Value(true),
            errorCode: const Value(null),
            nextRetryAt: const Value(null),
            lastProgressAt: Value(DateTime.now()),
          ),
        );
      }
      await ref.read(syncEngineProvider).sync(force: true);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le serveur est indisponible. La reprise automatique reste programmée.',
          ),
        ),
      );
    }
  }

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
              final ready = recording.status == 'ready';
              final failed = recording.status == 'failed';
              final pipeline = _RecordingPipeline(recording);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                children: [
                  Center(
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeOutCubic,
                            tween: Tween(end: pipeline.overallProgress),
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                                  value: ready ? 1 : value,
                                  strokeWidth: 6,
                                  color: failed
                                      ? AppColors.error
                                      : ready
                                      ? context.statusColors.success
                                      : AppColors.secondary,
                                  backgroundColor: AppColors.outline,
                                ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            child: Icon(
                              ready
                                  ? Icons.check_rounded
                                  : failed
                                  ? Icons.priority_high_rounded
                                  : Icons.graphic_eq_rounded,
                              key: ValueKey(recording.pipelineStage),
                              size: 39,
                              color: failed
                                  ? AppColors.error
                                  : ready
                                  ? context.statusColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ready
                        ? 'Cours prêt'
                        : failed
                        ? 'Action nécessaire'
                        : 'Votre cours avance',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RecordingSummaryCard(
                    courseTitle: courseTitle,
                    chapterTitle: chapter.title,
                    durationSeconds: recording.durationSecs ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _OverallProgressCard(
                    progress: pipeline.overallProgress,
                    message: pipeline.message,
                    failed: failed,
                    waiting: pipeline.isWaiting,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ready ? 'Traitement terminé' : 'Traitement en cours',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${recording.progressPercent.clamp(0, 100)} %',
                        style: TextStyle(
                          color: failed ? AppColors.error : AppColors.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProcessingStep(
                    number: 1,
                    title: 'Sauvegarde sur cet appareil',
                    subtitle: 'Terminé · disponible hors ligne',
                    state: _StepState.done,
                  ),
                  _ProcessingStep.fromView(
                    number: 2,
                    title: 'Envoi de l’enregistrement',
                    view: pipeline.step(
                      'upload',
                      fallbackProgress: recording.status == 'uploading'
                          ? uploadProgress
                          : null,
                    ),
                  ),
                  _ProcessingStep.fromView(
                    number: 3,
                    title: 'Transcription de l’audio',
                    view: pipeline.step('transcription'),
                  ),
                  _ProcessingStep.fromView(
                    number: 4,
                    title: 'Fusion avec les séances précédentes',
                    view: pipeline.step('consolidation'),
                  ),
                  _ProcessingStep.fromView(
                    number: 5,
                    title: 'Création du résumé, fiches et quiz',
                    view: pipeline.step('generation'),
                  ),
                  _ProcessingStep.fromView(
                    number: 6,
                    title: 'Finalisation du chapitre',
                    view: pipeline.step('finalization'),
                  ),
                  const SizedBox(height: 4),
                  if (phase == SyncPhase.offline || pipeline.isWaiting)
                    _OfflineNotice(
                      text:
                          'Vous pouvez fermer l’application. Le traitement reprendra automatiquement dès que la connexion sera disponible.',
                    )
                  else if (failed)
                    _OfflineNotice(
                      error: true,
                      text: recording.retryable
                          ? 'Le traitement sera relancé automatiquement. Vous pouvez aussi forcer une tentative maintenant.'
                          : pipeline.message,
                    ),
                  const SizedBox(height: 16),
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
                        : () => _continueOrRetry(context, ref, recording),
                    child: Text(
                      ready
                          ? 'Voir le résumé'
                          : failed && recording.serverRecordingId != null
                          ? 'Relancer le traitement'
                          : 'Synchroniser maintenant',
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

class _RecordingPipeline {
  const _RecordingPipeline(this.recording);

  final Recording recording;

  double get overallProgress => recording.progressPercent.clamp(0, 100) / 100;

  String get message =>
      recording.statusMessage ??
      switch (recording.status) {
        'pending_sync' => 'En attente d’une connexion au serveur',
        'uploading' => 'Envoi de l’audio en cours…',
        'processing' || 'synced' => 'Analyse du cours en cours…',
        'ready' => 'Tous vos supports sont disponibles',
        'failed' => 'Le traitement n’a pas pu être terminé',
        _ => 'Cours sauvegardé sur cet appareil',
      };

  bool get isWaiting =>
      recording.status == 'pending_sync' ||
      const {
        'saved_local',
        'waiting_network',
        'retry_wait',
      }.contains(recording.pipelineStage);

  _PipelineStepView step(String group, {double? fallbackProgress}) {
    final (start, end) = switch (group) {
      'upload' => (0, 40),
      'transcription' => (40, 68),
      'consolidation' => (68, 78),
      'generation' => (78, 94),
      _ => (94, 100),
    };
    final percent = recording.progressPercent.clamp(0, 100);
    if (recording.status == 'ready' || percent >= end) {
      return const _PipelineStepView(
        state: _StepState.done,
        subtitle: 'Terminé',
      );
    }

    final activeGroup = _groupForStage(recording.pipelineStage, percent);
    if (recording.status == 'failed' && activeGroup == group) {
      return _PipelineStepView(state: _StepState.failed, subtitle: message);
    }
    if (activeGroup == group && isWaiting) {
      return _PipelineStepView(state: _StepState.pending, subtitle: message);
    }
    if (activeGroup == group || (percent >= start && percent < end)) {
      return _PipelineStepView(
        state: _StepState.active,
        subtitle: message,
        progress: _stageProgress ?? fallbackProgress,
      );
    }
    return const _PipelineStepView(
      state: _StepState.pending,
      subtitle: 'En attente',
    );
  }

  double? get _stageProgress {
    final current = recording.stageCurrent;
    final total = recording.stageTotal;
    if (current == null || total == null || total <= 0) return null;
    return (current / total).clamp(0.0, 1.0);
  }

  String _groupForStage(String stage, int percent) => switch (stage) {
    'saved_local' || 'waiting_network' || 'uploading' => 'upload',
    'queued' ||
    'checking_access' ||
    'downloading_audio' ||
    'transcribing' => 'transcription',
    'transcription_ready' || 'consolidating_chapter' => 'consolidation',
    'generating_material' => 'generation',
    'saving_material' || 'ready' => 'finalization',
    _ when percent < 40 => 'upload',
    _ when percent < 68 => 'transcription',
    _ when percent < 78 => 'consolidation',
    _ when percent < 94 => 'generation',
    _ => 'finalization',
  };
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({
    required this.progress,
    required this.message,
    required this.failed,
    required this.waiting,
  });

  final double progress;
  final String message;
  final bool failed;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final color = failed
        ? AppColors.error
        : waiting
        ? AppColors.warning
        : AppColors.secondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                waiting ? Icons.cloud_queue_rounded : Icons.bolt_rounded,
                size: 19,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            tween: Tween(end: progress),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(20),
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
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

class _PipelineStepView {
  const _PipelineStepView({
    required this.state,
    required this.subtitle,
    this.progress,
  });

  final _StepState state;
  final String subtitle;
  final double? progress;
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.progress,
  });

  factory _ProcessingStep.fromView({
    required int number,
    required String title,
    required _PipelineStepView view,
  }) => _ProcessingStep(
    number: number,
    title: title,
    subtitle: view.subtitle,
    state: view.state,
    progress: view.progress,
  );

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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    subtitle,
                    key: ValueKey('$state:$subtitle'),
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ),
                if (state == _StepState.active) ...[
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOut,
                    tween: Tween(end: progress ?? 0),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: progress == null ? null : value,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.secondary,
                      backgroundColor: AppColors.secondary.withValues(
                        alpha: 0.12,
                      ),
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
