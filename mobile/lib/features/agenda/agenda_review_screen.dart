import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_theme.dart';
import '../../core/agenda_item.dart';
import '../../db/app_database.dart';
import '../../providers.dart';

/// Confirmation screen shared by the agenda scan and iCal import flows.
///
/// The user sees one editable card per parsed draft. Editing any field
/// keeps the changes local until they tap Save. Confirmed items are inserted
/// into Drift first, then the regular background sync pushes them to the API.
class AgendaReviewScreen extends ConsumerStatefulWidget {
  const AgendaReviewScreen({super.key, required this.drafts});
  final List<AgendaItemDraft> drafts;

  @override
  ConsumerState<AgendaReviewScreen> createState() => _AgendaReviewScreenState();
}

class _AgendaReviewScreenState extends ConsumerState<AgendaReviewScreen> {
  late List<AgendaItemDraft> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.drafts);
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    int saved = 0;
    try {
      for (var i = 0; i < _items.length; i++) {
        final it = _items[i];
        if (it.title.trim().isEmpty) continue;
        await db
            .into(db.agendaItems)
            .insert(
              AgendaItemsCompanion.insert(
                clientUuid: const Uuid().v4(),
                title: it.title.trim(),
                kind: Value(it.kind),
                subject: Value(it.subject),
                startsAt: Value(DateTime.tryParse(it.startsAt ?? '')),
                endsAt: Value(DateTime.tryParse(it.endsAt ?? '')),
                notes: Value(it.notes),
                location: Value(it.location),
                recurrence: Value(it.recurrence),
                recurrenceUntil: Value(
                  DateTime.tryParse(it.recurrenceUntil ?? ''),
                ),
                reminderMinutes: Value(it.reminderMinutes),
                chapterClientUuid: Value(it.chapterClientUuid),
              ),
            );
        saved++;
      }
      Future.microtask(() => ref.read(syncEngineProvider).sync());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$saved élément${saved == 1 ? '' : 's'} enregistré${saved == 1 ? '' : 's'} sur cet appareil.',
            ),
          ),
        );
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
        setState(() => _saving = false);
      }
    }
  }

  void _remove(int idx) => setState(() => _items.removeAt(idx));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review agenda (${_items.length})'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveAll,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save all',
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _DraftCard(
          key: ValueKey('agenda-draft-$i-${_items[i].title}'),
          draft: _items[i],
          onChanged: (next) => setState(() => _items[i] = next),
          onRemove: () => _remove(i),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final AgendaItemDraft draft;
  final ValueChanged<AgendaItemDraft> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: draft.title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => onChanged(draft.copyWith(title: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.startsAt ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Starts (ISO 8601)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => onChanged(
                      draft.copyWith(startsAt: v.isEmpty ? null : v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.endsAt ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Ends (ISO 8601)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        onChanged(draft.copyWith(endsAt: v.isEmpty ? null : v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: draft.notes ?? '',
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  onChanged(draft.copyWith(notes: v.isEmpty ? null : v)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
