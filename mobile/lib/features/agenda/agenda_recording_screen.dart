import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../providers.dart';
import '../../sync/background_sync.dart';
import '../recording/recorder_service.dart';

class AgendaRecordingScreen extends ConsumerStatefulWidget {
  const AgendaRecordingScreen({
    super.key,
    required this.chapterClientUuid,
    required this.title,
  });

  final String chapterClientUuid;
  final String title;

  @override
  ConsumerState<AgendaRecordingScreen> createState() =>
      _AgendaRecordingScreenState();
}

class _AgendaRecordingScreenState extends ConsumerState<AgendaRecordingScreen> {
  bool _starting = true;
  bool _recording = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final recorder = ref.read(recorderServiceProvider);
    try {
      if (!await recorder.hasPermission()) {
        throw StateError("L’autorisation du microphone est nécessaire.");
      }
      await recorder.start(chapterClientUuid: widget.chapterClientUuid);
      if (mounted) {
        setState(() {
          _starting = false;
          _recording = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    await ref.read(recorderServiceProvider).stop();
    unawaited(BackgroundSyncScheduler.enqueueWhenOnline());
    unawaited(ref.read(syncEngineProvider).sync());
    if (!mounted) return;
    setState(() => _recording = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enregistrement sauvegardé sur cet appareil.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _recording) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Arrêtez l’enregistrement avant de quitter."),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Enregistrement')),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: _recording
                        ? const Color(0xFFFDE8E5)
                        : const Color(0xFFFFE5DC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _recording ? Icons.graphic_eq_rounded : Icons.mic_none,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _starting
                      ? 'Préparation du microphone…'
                      : _error ??
                            (_recording
                                ? 'Enregistrement en cours'
                                : 'Enregistrement terminé'),
                  style: TextStyle(
                    color: _error == null ? AppColors.muted : AppColors.error,
                  ),
                ),
                const SizedBox(height: 36),
                if (_starting)
                  const CircularProgressIndicator()
                else if (_error != null)
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retour'),
                  )
                else if (_recording)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text("Arrêter l’enregistrement"),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Terminer'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
