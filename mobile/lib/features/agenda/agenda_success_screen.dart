import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import 'agenda_editor_screen.dart';
import 'agenda_style.dart';

class AgendaSuccessScreen extends ConsumerWidget {
  const AgendaSuccessScreen({super.key, required this.clientUuid});

  final String clientUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final stream = (db.select(
      db.agendaItems,
    )..where((row) => row.clientUuid.equals(clientUuid))).watchSingleOrNull();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Cours ajouté'),
      ),
      body: StreamBuilder<AgendaItem?>(
        stream: stream,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const Center(child: _SuccessMark()),
                const SizedBox(height: 16),
                AgendaSummaryCard(item: item),
                const SizedBox(height: 14),
                const _LocalBadge(),
                const SizedBox(height: 8),
                _SyncLine(pending: item.pendingSync),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text("Voir dans l’agenda"),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const AgendaEditorScreen(kind: 'course'),
                    ),
                  ),
                  child: const Text('Ajouter un autre cours'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: context.statusColors.successContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: 44,
        color: context.statusColors.success,
      ),
    );
  }
}

class _LocalBadge extends StatelessWidget {
  const _LocalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      decoration: BoxDecoration(
        color: context.statusColors.successContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_outlined,
            size: 17,
            color: context.statusColors.onSuccessContainer,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Enregistré sur cet appareil',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.statusColors.onSuccessContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.pending});
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final color = pending
        ? context.statusColors.warning
        : context.statusColors.success;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          pending ? Icons.sync_rounded : Icons.cloud_done_outlined,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 7),
        Text(
          pending ? 'Synchronisation en attente' : 'Synchronisé',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}

class AgendaSummaryCard extends StatelessWidget {
  const AgendaSummaryCard({
    super.key,
    required this.item,
    this.detailed = false,
  });

  final AgendaItem item;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final style = agendaKindStyle(item.kind);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(style.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (item.subject case final subject?)
                        Text(
                          subject,
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
            const Divider(height: 1),
            const SizedBox(height: 12),
            _SummaryRow(
              icon: Icons.calendar_today_outlined,
              text: item.startsAt == null
                  ? 'Date à définir'
                  : '${longFrenchDate(item.startsAt!)}  ·  '
                        '${agendaTime(item.startsAt)} – ${agendaTime(item.endsAt)}',
            ),
            if (item.location case final location?) ...[
              const SizedBox(height: 12),
              _SummaryRow(icon: Icons.location_on_outlined, text: location),
            ],
            if (detailed || item.recurrence == 'weekly') ...[
              const SizedBox(height: 12),
              _SummaryRow(
                icon: Icons.sync_rounded,
                text: item.recurrence == 'weekly'
                    ? 'Chaque semaine${item.recurrenceUntil == null ? '' : '\nSe termine le ${longFrenchDate(item.recurrenceUntil!, includeYear: true)}'}'
                    : 'Une fois',
              ),
            ],
            if (item.reminderMinutes case final minutes?) ...[
              const SizedBox(height: 12),
              _SummaryRow(
                icon: Icons.notifications_none_rounded,
                text: 'Rappel ${reminderLabel(minutes)}',
              ),
            ],
            if (detailed && item.notes != null) ...[
              const SizedBox(height: 12),
              _SummaryRow(icon: Icons.notes_rounded, text: item.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
        ),
      ],
    );
  }
}
