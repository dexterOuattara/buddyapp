import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(agendaStreamProvider).value ?? const [];
    final sorted = [...items]
      ..sort((a, b) => (a.startsAt ?? DateTime.now())
          .compareTo(b.startsAt ?? DateTime.now()));

    return Column(
      children: [
        Expanded(
          child: sorted.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _AgendaTile(item: sorted[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _showAddSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add to agenda'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    DateTime? startsAt;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New agenda item',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g. "Maths — Chapter 4 revision")',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(startsAt == null
                    ? 'Pick a date & time'
                    : DateFormat.yMMMd().add_jm().format(startsAt!)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  setSheetState(() {
                    startsAt = DateTime(
                        date.year, date.month, date.day,
                        time?.hour ?? 9, time?.minute ?? 0);
                  });
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final db = ref.read(databaseProvider);
                  await db.into(db.agendaItems).insert(
                        AgendaItemsCompanion.insert(
                          clientUuid: const Uuid().v4(),
                          title: title.text.trim(),
                          startsAt: Value(startsAt),
                        ),
                      );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.item});
  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final date = item.startsAt;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: const Icon(Icons.event_note, color: Colors.indigo),
        ),
        title: Text(item.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(date == null
            ? 'No date set'
            : DateFormat.yMMMEd().add_jm().format(date)),
        trailing: item.pendingSync
            ? const Icon(Icons.cloud_upload, size: 18, color: Colors.orange)
            : const Icon(Icons.cloud_done, size: 18, color: Colors.green),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Your agenda is empty',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Plan your classes so you know what to prepare for.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
