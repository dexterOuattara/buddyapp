import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';
import '../../providers.dart';
import 'agenda_style.dart';
import 'agenda_success_screen.dart';

class AgendaEditorScreen extends ConsumerStatefulWidget {
  const AgendaEditorScreen({super.key, this.kind = 'course', this.item});

  final String kind;
  final AgendaItem? item;

  @override
  ConsumerState<AgendaEditorScreen> createState() => _AgendaEditorScreenState();
}

class _AgendaEditorScreenState extends ConsumerState<AgendaEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _subject;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _weekly;
  late DateTime _recurrenceUntil;
  late int? _reminderMinutes;
  int _step = 0;
  bool _saving = false;

  bool get _editing => widget.item != null;
  String get _kind => widget.item?.kind ?? widget.kind;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final now = DateTime.now();
    final roundedHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final startsAt = item?.startsAt?.toLocal() ?? roundedHour;
    final endsAt =
        item?.endsAt?.toLocal() ??
        startsAt.add(const Duration(hours: 1, minutes: 30));
    _title = TextEditingController(text: item?.title ?? '');
    _subject = TextEditingController(text: item?.subject ?? '');
    _location = TextEditingController(text: item?.location ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _date = dateOnly(startsAt);
    _start = TimeOfDay.fromDateTime(startsAt);
    _end = TimeOfDay.fromDateTime(endsAt);
    _weekly = item?.recurrence == 'weekly';
    _recurrenceUntil =
        item?.recurrenceUntil?.toLocal() ??
        _date.add(const Duration(days: 120));
    _reminderMinutes = item?.reminderMinutes ?? 10;
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate({bool recurrenceEnd = false}) async {
    final initial = recurrenceEnd ? _recurrenceUntil : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: recurrenceEnd
          ? _date
          : DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (recurrenceEnd) {
        _recurrenceUntil = picked;
      } else {
        _date = picked;
        if (_recurrenceUntil.isBefore(picked)) {
          _recurrenceUntil = picked.add(const Duration(days: 120));
        }
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final startsAt = _combine(_date, _start);
    final endsAt = _combine(_date, _end);
    if (!endsAt.isAfter(startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'heure de fin doit suivre le début.")),
      );
      return;
    }
    setState(() => _step = 1);
  }

  Future<String?> _ensureChapter(AppDatabase db) async {
    if (_kind == 'reminder') return null;
    if (widget.item?.chapterClientUuid case final existing?) return existing;

    final courseTitle = _title.text.trim();
    final allCourses = await (db.select(
      db.courses,
    )..where((row) => row.deleted.equals(false))).get();
    Course? course;
    for (final candidate in allCourses) {
      if (candidate.title.toLowerCase() == courseTitle.toLowerCase()) {
        course = candidate;
        break;
      }
    }
    final courseUuid = course?.clientUuid ?? const Uuid().v4();
    if (course == null) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion.insert(
              clientUuid: courseUuid,
              title: courseTitle,
              description: Value(
                _subject.text.trim().isEmpty ? null : _subject.text.trim(),
              ),
            ),
          );
    }

    final lessonTitle = _subject.text.trim().isEmpty
        ? 'Cours planifié'
        : _subject.text.trim();
    final lessonUuid = const Uuid().v4();
    final chapterUuid = const Uuid().v4();
    await db
        .into(db.lessons)
        .insert(
          LessonsCompanion.insert(
            clientUuid: lessonUuid,
            courseClientUuid: courseUuid,
            title: lessonTitle,
          ),
        );
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            clientUuid: chapterUuid,
            lessonClientUuid: lessonUuid,
            title: lessonTitle,
          ),
        );
    return chapterUuid;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      if (_reminderMinutes != null) {
        await ref.read(agendaReminderServiceProvider).requestPermission();
      }
      final startsAt = _combine(_date, _start);
      final endsAt = _combine(_date, _end);
      final chapterUuid = await _ensureChapter(db);
      final companion = AgendaItemsCompanion(
        title: Value(_title.text.trim()),
        kind: Value(_kind),
        subject: Value(_emptyToNull(_subject.text)),
        notes: Value(_emptyToNull(_notes.text)),
        location: Value(_emptyToNull(_location.text)),
        startsAt: Value(startsAt),
        endsAt: Value(endsAt),
        recurrence: Value(_weekly ? 'weekly' : 'none'),
        recurrenceUntil: Value(_weekly ? dateOnly(_recurrenceUntil) : null),
        reminderMinutes: Value(_reminderMinutes),
        chapterClientUuid: Value(chapterUuid),
        pendingSync: const Value(true),
        deleted: const Value(false),
        updatedAt: Value(DateTime.now()),
      );

      late final String clientUuid;
      if (_editing) {
        clientUuid = widget.item!.clientUuid;
        await (db.update(
          db.agendaItems,
        )..where((row) => row.clientUuid.equals(clientUuid))).write(companion);
      } else {
        clientUuid = const Uuid().v4();
        await db
            .into(db.agendaItems)
            .insert(
              AgendaItemsCompanion.insert(
                clientUuid: clientUuid,
                title: _title.text.trim(),
                kind: Value(_kind),
                subject: Value(_emptyToNull(_subject.text)),
                notes: Value(_emptyToNull(_notes.text)),
                location: Value(_emptyToNull(_location.text)),
                startsAt: Value(startsAt),
                endsAt: Value(endsAt),
                recurrence: Value(_weekly ? 'weekly' : 'none'),
                recurrenceUntil: Value(
                  _weekly ? dateOnly(_recurrenceUntil) : null,
                ),
                reminderMinutes: Value(_reminderMinutes),
                chapterClientUuid: Value(chapterUuid),
              ),
            );
      }
      Future.microtask(() => ref.read(syncEngineProvider).sync());
      if (!mounted) return;
      if (_editing) {
        Navigator.pop(context, true);
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AgendaSuccessScreen(clientUuid: clientUuid),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing
        ? 'Modifier'
        : _kind == 'course'
        ? 'Nouveau cours'
        : _kind == 'revision'
        ? 'Nouvelle révision'
        : 'Nouveau rappel';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _step == 0
              ? () => Navigator.pop(context)
              : () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == 0 ? _informationStep() : _repeatStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: FilledButton(
                onPressed: _saving ? null : (_step == 0 ? _continue : _save),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _step == 0
                            ? 'Continuer'
                            : _editing
                            ? 'Enregistrer les modifications'
                            : "Ajouter à l’agenda",
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.secondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _informationStep() {
    final primaryLabel = _kind == 'reminder' ? 'Nom du rappel' : 'Nom du cours';
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('information'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        children: [
          _stepLabel('1 sur 2  ·  Informations'),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: primaryLabel),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ce champ est obligatoire.'
                : null,
          ),
          const SizedBox(height: 12),
          if (_kind != 'reminder') ...[
            TextField(
              controller: _subject,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Chapitre ou sujet'),
            ),
            const SizedBox(height: 12),
          ],
          _PickerField(
            label: 'Date',
            value: longFrenchDate(_date),
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: 'Début',
                  value: _start.format(context),
                  icon: Icons.schedule_rounded,
                  onTap: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerField(
                  label: 'Fin',
                  value: _end.format(context),
                  icon: Icons.schedule_rounded,
                  onTap: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Lieu',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ajouter une note',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _repeatStep() {
    return ListView(
      key: const ValueKey('repeat'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        _stepLabel('2 sur 2  ·  Répétition et rappel'),
        Text('Répétition', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Une fois')),
            ButtonSegment(value: true, label: Text('Chaque semaine')),
          ],
          selected: {_weekly},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              setState(() => _weekly = selection.first),
        ),
        if (_weekly) ...[
          const SizedBox(height: 22),
          Text(
            'Répéter chaque semaine le',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 7; i++)
                _WeekdayChip(day: i, selected: i == _date.weekday),
            ],
          ),
          const SizedBox(height: 16),
          _PickerField(
            label: 'Se termine',
            value: longFrenchDate(_recurrenceUntil, includeYear: true),
            icon: Icons.calendar_today_outlined,
            onTap: () => _pickDate(recurrenceEnd: true),
          ),
        ],
        const SizedBox(height: 24),
        Text('Rappel', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const <int?>[10, 30, 60, null])
              ChoiceChip(
                label: Text(reminderLabel(option)),
                selected: _reminderMinutes == option,
                onSelected: (_) => setState(() => _reminderMinutes = option),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Disponible hors ligne')),
              IgnorePointer(
                child: Switch(
                  value: true,
                  activeTrackColor: AppColors.success,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({required this.day, required this.selected});
  final int day;
  final bool selected;

  static const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.secondary : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.secondary : AppColors.outline,
        ),
      ),
      child: Text(
        labels[day - 1],
        style: TextStyle(
          color: selected ? Colors.white : AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
