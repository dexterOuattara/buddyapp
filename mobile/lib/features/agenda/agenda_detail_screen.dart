import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import 'agenda_editor_screen.dart';
import 'agenda_recording_screen.dart';
import 'agenda_success_screen.dart';

class AgendaDetailScreen extends ConsumerWidget {
  const AgendaDetailScreen({super.key, required this.clientUuid});

  final String clientUuid;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AgendaItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: const Text(
          'Il disparaîtra de cet appareil et la suppression sera '
          'synchronisée lors de votre prochaine connexion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final db = ref.read(databaseProvider);
    await (db.update(
      db.agendaItems,
    )..where((row) => row.clientUuid.equals(item.clientUuid))).write(
      AgendaItemsCompanion(
        deleted: const Value(true),
        pendingSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    Future.microtask(() => ref.read(syncEngineProvider).sync());
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final stream = (db.select(
      db.agendaItems,
    )..where((row) => row.clientUuid.equals(clientUuid))).watchSingleOrNull();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du cours'),
        actions: [
          IconButton(
            tooltip: 'Plus d’options',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: StreamBuilder<AgendaItem?>(
        stream: stream,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (item.deleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            });
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                AgendaSummaryCard(item: item, detailed: true),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: item.chapterClientUuid == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AgendaRecordingScreen(
                              chapterClientUuid: item.chapterClientUuid!,
                              title: item.title,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.graphic_eq_rounded),
                  label: const Text("Démarrer l’enregistrement"),
                ),
                if (item.chapterClientUuid == null) ...[
                  const SizedBox(height: 7),
                  const Text(
                    'Associez cet événement à un chapitre pour enregistrer le cours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AgendaEditorScreen(item: item),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        onPressed: () => _delete(context, ref, item),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.statusColors.warningContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cloud_outlined, size: 21),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Les modifications sont enregistrées sur cet appareil '
                          'et seront synchronisées dès que vous serez en ligne.',
                          style: TextStyle(fontSize: 12, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
