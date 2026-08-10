import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';

const _transcriptCueExtent = 76.0;
const _maxTranscriptViewportHeight = 228.0;
const _minTranscriptViewportHeight = 84.0;

class RecordingPlayerScreen extends ConsumerStatefulWidget {
  const RecordingPlayerScreen({
    super.key,
    required this.recording,
    required this.chapterTitle,
    this.courseTitle,
  });

  final Recording recording;
  final String chapterTitle;
  final String? courseTitle;

  @override
  ConsumerState<RecordingPlayerScreen> createState() =>
      _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends ConsumerState<RecordingPlayerScreen> {
  late final AudioPlayer _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _transcriptController = ScrollController();
  final _transcriptCardKey = GlobalKey();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  double _speed = 1;
  bool _preparing = true;
  bool _regenerating = false;
  String? _error;
  String? _transcriptNotice;
  Transcript? _transcript;
  List<TranscriptCue> _segments = const [];
  int _activeSegment = -1;

  bool get _playing => _state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _state = state);
      }),
      _player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
      _player.onPositionChanged.listen((position) {
        if (mounted) _updatePosition(position);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          _updatePosition(_duration);
          setState(() => _state = PlayerState.completed);
        }
      }),
    ]);
    final db = ref.read(databaseProvider);
    _subscriptions.add(
      (db.select(db.transcripts)..where(
            (row) =>
                row.recordingClientUuid.equals(widget.recording.clientUuid),
          ))
          .watchSingleOrNull()
          .listen(_updateTranscript),
    );
    unawaited(_prepare());
  }

  void _updateTranscript(Transcript? transcript) {
    if (!mounted) return;
    final segments = transcript == null
        ? const <TranscriptCue>[]
        : parseTranscriptSegments(transcript.segmentsJson);
    final available =
        transcript != null &&
        (transcript.content.trim().isNotEmpty || segments.isNotEmpty);
    final active = activeTranscriptSegmentIndex(segments, _position);
    setState(() {
      _transcript = available ? transcript : null;
      _segments = available ? segments : const [];
      _activeSegment = available ? active : -1;
    });
    if (available && active >= 0) {
      _scrollToSegment(active, animate: false);
    }
  }

  void _updatePosition(Duration position) {
    final active = activeTranscriptSegmentIndex(_segments, position);
    final changed = active != _activeSegment;
    setState(() {
      _position = position;
      _activeSegment = active;
    });
    if (changed && active >= 0) _scrollToSegment(active);
  }

  void _scrollToSegment(int index, {bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_transcriptController.hasClients) return;
      final target = (index * _transcriptCueExtent - _transcriptCueExtent)
          .clamp(0.0, _transcriptController.position.maxScrollExtent);
      if (animate) {
        _transcriptController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _transcriptController.jumpTo(target);
      }
    });
  }

  Future<void> _prepare() async {
    final file = File(widget.recording.localPath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _preparing = false;
          _error = 'Le fichier audio n’est plus disponible sur cet appareil.';
        });
      }
      return;
    }
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(DeviceFileSource(widget.recording.localPath));
      final duration = await _player.getDuration();
      if (mounted) {
        setState(() {
          _duration =
              duration ?? Duration(seconds: widget.recording.durationSecs ?? 0);
          _preparing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preparing = false;
          _error = 'Impossible d’ouvrir cet enregistrement.';
        });
      }
    }
  }

  Future<void> _toggle() async {
    if (_preparing || _error != null) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        if (_state == PlayerState.completed || _position >= _duration) {
          await _player.seek(Duration.zero);
        }
        await _player.resume();
        _revealTranscript();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'La lecture a été interrompue.');
    }
  }

  Future<void> _seek(Duration target) async {
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > _duration
        ? _duration
        : target;
    await _player.seek(clamped);
    if (mounted) _updatePosition(clamped);
  }

  Future<void> _seekAndPlay(TranscriptCue cue) async {
    await _seek(Duration(milliseconds: cue.startMs));
    if (!_playing && _error == null) await _player.resume();
  }

  Future<void> _changeSpeed(double speed) async {
    await _player.setPlaybackRate(speed);
    if (mounted) setState(() => _speed = speed);
  }

  void _revealTranscript() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transcriptContext = _transcriptCardKey.currentContext;
      if (!mounted || transcriptContext == null) return;
      Scrollable.ensureVisible(
        transcriptContext,
        alignment: 0.06,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _regenerateTranscript() async {
    final recordingId = widget.recording.serverRecordingId;
    if (recordingId == null || _regenerating) return;
    setState(() {
      _regenerating = true;
      _transcriptNotice = null;
    });
    try {
      await ref.read(apiClientProvider).reprocessRecording(recordingId);
      await (ref
              .read(databaseProvider)
              .update(ref.read(databaseProvider).recordings)
            ..where((row) => row.id.equals(widget.recording.id)))
          .write(const RecordingsCompanion(status: Value('processing')));
      if (mounted) {
        setState(() {
          _transcriptNotice =
              'Transcription synchronisée relancée. Elle apparaîtra ici automatiquement.';
        });
      }
      unawaited(ref.read(syncEngineProvider).sync(force: true));
    } catch (_) {
      if (mounted) {
        setState(() {
          _transcriptNotice =
              'Impossible de relancer la transcription pour le moment.';
        });
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _transcriptController.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMilliseconds = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final positionMilliseconds = _position.inMilliseconds
        .clamp(0, maxMilliseconds.toInt())
        .toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.11),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.courseTitle case final course?) ...[
                        const SizedBox(height: 1),
                        Text(
                          course,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          "d MMMM yyyy · HH:mm",
                          'fr',
                        ).format(widget.recording.createdAt),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 42,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          progress: maxMilliseconds <= 1
                              ? 0
                              : positionMilliseconds / maxMilliseconds,
                        ),
                      ),
                    ),
                    Slider(
                      value: positionMilliseconds,
                      max: maxMilliseconds,
                      activeColor: AppColors.secondary,
                      inactiveColor: AppColors.outline,
                      onChanged: _preparing || _error != null
                          ? null
                          : (value) {
                              setState(
                                () => _position = Duration(
                                  milliseconds: value.round(),
                                ),
                              );
                            },
                      onChangeEnd: (value) =>
                          _seek(Duration(milliseconds: value.round())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Row(
                        children: [
                          Text(
                            formatPlaybackTime(_position),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatPlaybackTime(_duration),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Reculer de 10 secondes',
                          onPressed: _error == null
                              ? () => _seek(
                                  _position - const Duration(seconds: 10),
                                )
                              : null,
                          icon: const Icon(Icons.replay_10_rounded),
                          iconSize: 28,
                        ),
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            onPressed: _preparing || _error != null
                                ? null
                                : _toggle,
                            child: _preparing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 36,
                                  ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Avancer de 10 secondes',
                          onPressed: _error == null
                              ? () => _seek(
                                  _position + const Duration(seconds: 10),
                                )
                              : null,
                          icon: const Icon(Icons.forward_10_rounded),
                          iconSize: 28,
                        ),
                        PopupMenuButton<double>(
                          tooltip: 'Vitesse de lecture',
                          padding: EdgeInsets.zero,
                          initialValue: _speed,
                          onSelected: _changeSpeed,
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 0.75, child: Text('0,75×')),
                            PopupMenuItem(
                              value: 1,
                              child: Text('Vitesse normale'),
                            ),
                            PopupMenuItem(value: 1.25, child: Text('1,25×')),
                            PopupMenuItem(value: 1.5, child: Text('1,5×')),
                            PopupMenuItem(value: 2, child: Text('2×')),
                          ],
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            avatar: const Icon(Icons.speed_rounded, size: 16),
                            label: Text(
                              '${_speed.toStringAsFixed(_speed == 1 ? 0 : 2)}×',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _transcriptCardKey,
              child: _buildTranscriptCard(context),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.offline_pin_outlined,
                  size: 17,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'Disponible hors ligne',
                  style: TextStyle(
                    color: context.statusColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptCard(BuildContext context) {
    final transcript = _transcript;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.subtitles_rounded, color: AppColors.secondary),
                const SizedBox(width: 9),
                Text(
                  'Transcription',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_segments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Synchronisée',
                      style: TextStyle(
                        color: context.statusColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (transcript == null)
              _TranscriptUnavailable(
                processing:
                    widget.recording.status == 'processing' || _regenerating,
              )
            else if (_segments.isEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    transcript.content,
                    style: const TextStyle(height: 1.55),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cette ancienne transcription est conservée, mais elle ne contient pas encore de repères temporels.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (widget.recording.serverRecordingId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _regenerating ? null : _regenerateTranscript,
                    icon: _regenerating
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Synchroniser cette transcription'),
                  ),
                ),
              ],
            ] else ...[
              const Text(
                'Touchez une phrase pour reprendre l’audio à cet endroit.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 7),
              Container(
                height: transcriptViewportHeight(_segments.length),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  controller: _transcriptController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemExtent: _transcriptCueExtent,
                  itemCount: _segments.length,
                  itemBuilder: (context, index) {
                    final cue = _segments[index];
                    final active = index == _activeSegment;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      child: Material(
                        color: active
                            ? AppColors.secondary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          key: ValueKey('transcript-cue-$index'),
                          borderRadius: BorderRadius.circular(11),
                          onTap: () => _seekAndPlay(cue),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    formatPlaybackTime(
                                      Duration(milliseconds: cue.startMs),
                                    ),
                                    style: TextStyle(
                                      color: active
                                          ? AppColors.secondary
                                          : AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _SynchronizedTranscriptText(
                                    cue: cue,
                                    position: _position,
                                    active: active,
                                  ),
                                ),
                                if (active)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4, top: 2),
                                    child: Icon(
                                      Icons.graphic_eq_rounded,
                                      size: 16,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_transcriptNotice case final notice?) ...[
              const SizedBox(height: 12),
              Text(
                notice,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SynchronizedTranscriptText extends StatelessWidget {
  const _SynchronizedTranscriptText({
    required this.cue,
    required this.position,
    required this.active,
  });

  final TranscriptCue cue;
  final Duration position;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (cue.words.isEmpty) {
      return Text(
        cue.text,
        style: TextStyle(
          height: 1.45,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.ink : AppColors.muted,
        ),
      );
    }

    final currentWord = active ? activeTranscriptWordIndex(cue, position) : -1;
    final positionMs = position.inMilliseconds;
    return Semantics(
      label: cue.text,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (var index = 0; index < cue.words.length; index++)
              _AnimatedTranscriptWord(
                word: cue.words[index],
                current: index == currentWord,
                spoken: positionMs >= cue.words[index].endMs,
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTranscriptWord extends StatelessWidget {
  const _AnimatedTranscriptWord({
    required this.word,
    required this.current,
    required this.spoken,
  });

  final TranscriptWordCue word;
  final bool current;
  final bool spoken;

  @override
  Widget build(BuildContext context) {
    final color = current
        ? Colors.white
        : spoken
        ? AppColors.secondary
        : AppColors.muted;
    return AnimatedScale(
      scale: current ? 1.06 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: current ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: current
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            height: 1.3,
            fontSize: 14,
            fontWeight: current || spoken ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
          child: Text(word.text),
        ),
      ),
    );
  }
}

class _TranscriptUnavailable extends StatelessWidget {
  const _TranscriptUnavailable({required this.processing});

  final bool processing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (processing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.subtitles_off_rounded, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              processing
                  ? 'Transcription en cours de création…'
                  : 'Transcription pas disponible',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class TranscriptCue {
  const TranscriptCue({
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.words,
  });

  final int startMs;
  final int endMs;
  final String text;
  final List<TranscriptWordCue> words;
}

class TranscriptWordCue {
  const TranscriptWordCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;
}

/// A stored row only represents an available transcript when it has usable
/// text or at least one valid synchronized cue. Historical providers could
/// create empty rows, which must be displayed as unavailable.
bool transcriptIsAvailable(Transcript? transcript) {
  if (transcript == null) return false;
  if (transcript.content.trim().isNotEmpty) return true;
  return parseTranscriptSegments(transcript.segmentsJson).isNotEmpty;
}

double transcriptViewportHeight(int cueCount) {
  final contentHeight = cueCount * _transcriptCueExtent + 8;
  return contentHeight
      .clamp(_minTranscriptViewportHeight, _maxTranscriptViewportHeight)
      .toDouble();
}

List<TranscriptCue> parseTranscriptSegments(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final segments =
        decoded
            .whereType<Map>()
            .map((item) {
              final start = _jsonInt(item['start_ms']);
              final end = _jsonInt(item['end_ms']);
              final text = item['text']?.toString().trim() ?? '';
              if (start == null ||
                  end == null ||
                  end <= start ||
                  text.isEmpty) {
                return null;
              }
              final words = parseTranscriptWords(
                item['words'],
                segmentText: text,
                segmentStartMs: start,
                segmentEndMs: end,
              );
              return TranscriptCue(
                startMs: start,
                endMs: end,
                text: text,
                words: words,
              );
            })
            .whereType<TranscriptCue>()
            .toList(growable: false)
          ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return segments
        .expand(splitTranscriptCueForDisplay)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

/// Whisper segments can contain several lines of text. Smaller display cues
/// keep the active word inside the visible transcript viewport while audio is
/// playing, without altering any provider timestamps.
List<TranscriptCue> splitTranscriptCueForDisplay(
  TranscriptCue cue, {
  int maxWords = 8,
}) {
  if (cue.words.length <= maxWords || maxWords < 1) return [cue];
  final chunks = <TranscriptCue>[];
  for (var start = 0; start < cue.words.length; start += maxWords) {
    final end = (start + maxWords).clamp(0, cue.words.length);
    final words = cue.words.sublist(start, end);
    chunks.add(
      TranscriptCue(
        startMs: words.first.startMs,
        endMs: words.last.endMs,
        text: words.map((word) => word.text).join(' '),
        words: words,
      ),
    );
  }
  return chunks;
}

List<TranscriptWordCue> parseTranscriptWords(
  dynamic raw, {
  required String segmentText,
  required int segmentStartMs,
  required int segmentEndMs,
}) {
  final words =
      (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((item) {
            final rawStart = _jsonInt(item['start_ms']);
            final rawEnd = _jsonInt(item['end_ms']);
            final text = item['text']?.toString().trim() ?? '';
            if (rawStart == null || rawEnd == null || text.isEmpty) return null;
            final start = rawStart.clamp(segmentStartMs, segmentEndMs - 1);
            final end = rawEnd.clamp(start + 1, segmentEndMs);
            if (end <= start) return null;
            return TranscriptWordCue(startMs: start, endMs: end, text: text);
          })
          .whereType<TranscriptWordCue>()
          .toList(growable: false)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
  return words.isEmpty
      ? estimateTranscriptWords(
          segmentText,
          startMs: segmentStartMs,
          endMs: segmentEndMs,
        )
      : words;
}

List<TranscriptWordCue> estimateTranscriptWords(
  String text, {
  required int startMs,
  required int endMs,
}) {
  if (endMs <= startMs) return const [];
  final tokens = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return const [];

  final weights = tokens
      .map((token) => token.runes.length.clamp(1, 1 << 20))
      .toList(growable: false);
  final totalWeight = weights.fold<int>(0, (sum, weight) => sum + weight);
  final duration = endMs - startMs;
  var elapsedWeight = 0;
  return List.generate(tokens.length, (index) {
    final wordStart = startMs + duration * elapsedWeight ~/ totalWeight;
    elapsedWeight += weights[index];
    final wordEnd = index == tokens.length - 1
        ? endMs
        : startMs + duration * elapsedWeight ~/ totalWeight;
    return TranscriptWordCue(
      startMs: wordStart.clamp(startMs, endMs - 1),
      endMs: wordEnd.clamp(wordStart + 1, endMs),
      text: tokens[index],
    );
  });
}

int activeTranscriptSegmentIndex(
  List<TranscriptCue> segments,
  Duration position,
) {
  if (segments.isEmpty) return -1;
  final milliseconds = position.inMilliseconds;
  var active = -1;
  for (var index = 0; index < segments.length; index++) {
    if (segments[index].startMs > milliseconds) break;
    active = index;
  }
  return active;
}

int activeTranscriptWordIndex(TranscriptCue cue, Duration position) {
  if (cue.words.isEmpty ||
      position.inMilliseconds < cue.startMs ||
      position.inMilliseconds >= cue.endMs) {
    return -1;
  }
  final milliseconds = position.inMilliseconds;
  for (var index = 0; index < cue.words.length; index++) {
    final word = cue.words[index];
    if (milliseconds >= word.startMs && milliseconds < word.endMs) {
      return index;
    }
  }
  return -1;
}

int? _jsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.progress});
  final double progress;

  static const _bars = <double>[
    .28,
    .54,
    .82,
    .42,
    .68,
    .94,
    .58,
    .36,
    .76,
    .48,
    .88,
    .62,
    .34,
    .72,
    .98,
    .52,
    .78,
    .44,
    .66,
    .86,
    .38,
    .70,
    .56,
    .92,
    .46,
    .74,
    .32,
    .64,
    .84,
    .50,
    .96,
    .60,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / _bars.length;
    final width = (gap * .42).clamp(2.0, 5.0);
    for (var i = 0; i < _bars.length; i++) {
      final centerX = gap * i + gap / 2;
      final height = size.height * _bars[i];
      final played = centerX / size.width <= progress;
      final paint = Paint()
        ..color = played ? AppColors.secondary : AppColors.outline
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(centerX, (size.height - height) / 2),
        Offset(centerX, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

String formatPlaybackTime(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
