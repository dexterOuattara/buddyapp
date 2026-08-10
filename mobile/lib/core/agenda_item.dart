/// One agenda item as extracted from a photo (OCR) or an iCal feed.
///
/// The mobile app shows a list of these in a confirmation screen. The
/// user edits fields and taps Save; we persist each item locally before the
/// regular offline-first sync pushes it to `POST /api/agenda`.
class AgendaItemDraft {
  final String title;
  final String kind;
  final String? subject;
  final String? startsAt;
  final String? endsAt;
  final String? notes;
  final String? location;
  final String recurrence;
  final String? recurrenceUntil;
  final int? reminderMinutes;
  final String? chapterClientUuid;

  const AgendaItemDraft({
    required this.title,
    this.kind = 'course',
    this.subject,
    this.startsAt,
    this.endsAt,
    this.notes,
    this.location,
    this.recurrence = 'none',
    this.recurrenceUntil,
    this.reminderMinutes,
    this.chapterClientUuid,
  });

  factory AgendaItemDraft.fromJson(Map<String, dynamic> json) =>
      AgendaItemDraft(
        title: (json['title'] ?? '').toString(),
        kind: (json['kind'] ?? 'course').toString(),
        subject: json['subject'] as String?,
        startsAt: json['starts_at'] as String?,
        endsAt: json['ends_at'] as String?,
        notes: json['notes'] as String?,
        location: json['location'] as String?,
        recurrence: (json['recurrence'] ?? 'none').toString(),
        recurrenceUntil: json['recurrence_until'] as String?,
        reminderMinutes: json['reminder_minutes'] as int?,
        chapterClientUuid: json['chapter_client_uuid'] as String?,
      );

  AgendaItemDraft copyWith({
    String? title,
    String? kind,
    String? subject,
    String? startsAt,
    String? endsAt,
    String? notes,
    String? location,
    String? recurrence,
    String? recurrenceUntil,
    int? reminderMinutes,
    String? chapterClientUuid,
  }) => AgendaItemDraft(
    title: title ?? this.title,
    kind: kind ?? this.kind,
    subject: subject ?? this.subject,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    notes: notes ?? this.notes,
    location: location ?? this.location,
    recurrence: recurrence ?? this.recurrence,
    recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    chapterClientUuid: chapterClientUuid ?? this.chapterClientUuid,
  );

  @override
  String toString() =>
      'AgendaItemDraft(title: $title, kind: $kind, subject: $subject, '
      'starts: $startsAt, ends: $endsAt, location: $location, '
      'recurrence: $recurrence, reminder: $reminderMinutes)';
}
