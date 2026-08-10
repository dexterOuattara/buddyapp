import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import 'agenda_detail_screen.dart';
import 'agenda_editor_screen.dart';
import 'agenda_scan_screen.dart';
import 'agenda_style.dart';
import 'ical_import_screen.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, this.initialDate, this.referenceDate});

  /// Optional deterministic starting date used by previews and golden tests.
  final DateTime? initialDate;

  /// Optional clock value for deterministic previews and golden tests.
  final DateTime? referenceDate;

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = dateOnly(widget.initialDate ?? DateTime.now());
  }

  List<DateTime> get _visibleDays {
    final monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - DateTime.monday),
    );
    return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(agendaStreamProvider).value ?? const [];
    final items =
        allItems
            .where((item) => agendaItemOccursOn(item, _selectedDate))
            .toList()
          ..sort(
            (a, b) => (a.startsAt ?? DateTime(2100)).compareTo(
              b.startsAt ?? DateTime(2100),
            ),
          );

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _dateHeader()),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyAgenda(date: _selectedDate),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AgendaCard(
                    item: items[index],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AgendaDetailScreen(
                          clientUuid: items[index].clientUuid,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 22,
          child: FloatingActionButton(
            heroTag: 'agenda-add',
            tooltip: "Ajouter à l’agenda",
            onPressed: _showAddSheet,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _dateHeader() {
    final today = dateOnly(widget.referenceDate ?? DateTime.now());
    final caption = isSameDay(_selectedDate, today)
        ? "Aujourd’hui"
        : longFrenchDate(_selectedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _visibleDays.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = _visibleDays[index];
                return _DateCell(
                  date: date,
                  selected: isSameDay(date, _selectedDate),
                  onTap: () => setState(() => _selectedDate = date),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _AddAgendaSheet(
        onChoose: (kind) {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AgendaEditorScreen(kind: kind)),
          );
        },
        onScan: () {
          Navigator.pop(sheetContext);
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AgendaScanScreen()));
        },
        onImport: () {
          Navigator.pop(sheetContext);
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ICalImportScreen()));
        },
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 57,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortWeekday(date),
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.item, required this.onTap});

  final AgendaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = agendaKindStyle(item.kind);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 49,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agendaTime(item.startsAt),
                      style: TextStyle(
                        color: style.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      agendaTime(item.endsAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 56, color: AppColors.outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: style.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (item.subject case final subject?) ...[
                      const SizedBox(height: 3),
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (item.location case final location?) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5DC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aucun événement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Votre journée est libre. Ajoutez un cours, une révision ou un rappel.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAgendaSheet extends StatelessWidget {
  const _AddAgendaSheet({
    required this.onChoose,
    required this.onScan,
    required this.onImport,
  });

  final ValueChanged<String> onChoose;
  final VoidCallback onScan;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Ajouter à l’agenda",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AddOption(
            title: 'Programmer un cours',
            subtitle: 'Ajouter un cours régulier ou unique',
            icon: Icons.event_available_outlined,
            color: AppColors.primary,
            emphasized: true,
            onTap: () => onChoose('course'),
          ),
          const SizedBox(height: 10),
          _AddOption(
            title: 'Planifier une révision',
            subtitle: 'Préparer un examen ou revoir un chapitre',
            icon: Icons.menu_book_rounded,
            color: AppColors.secondary,
            onTap: () => onChoose('revision'),
          ),
          const SizedBox(height: 10),
          _AddOption(
            title: 'Ajouter un rappel',
            subtitle: 'Ne rien oublier',
            icon: Icons.notifications_none_rounded,
            color: AppColors.warning,
            onTap: () => onChoose('reminder'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scanner'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Importer iCal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: emphasized ? color : AppColors.outline,
          width: emphasized ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
        ),
      ),
    );
  }
}
