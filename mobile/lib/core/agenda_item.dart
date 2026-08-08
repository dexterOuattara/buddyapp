/// One agenda item as extracted from a photo (OCR) or an iCal feed.
///
/// The mobile app shows a list of these in a confirmation screen. The
/// user edits fields and taps Save; we then upsert each into
/// `agenda_items` via `POST /api/agenda`.
class AgendaItemDraft {
  final String title;
  final String? startsAt;
  final String? endsAt;
  final String? notes;

  const AgendaItemDraft({
    required this.title,
    this.startsAt,
    this.endsAt,
    this.notes,
  });

  factory AgendaItemDraft.fromJson(Map<String, dynamic> json) => AgendaItemDraft(
        title: (json['title'] ?? '').toString(),
        startsAt: json['starts_at'] as String?,
        endsAt: json['ends_at'] as String?,
        notes: json['notes'] as String?,
      );

  AgendaItemDraft copyWith({
    String? title,
    String? startsAt,
    String? endsAt,
    String? notes,
  }) =>
      AgendaItemDraft(
        title: title ?? this.title,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        notes: notes ?? this.notes,
      );

  @override
  String toString() =>
      'AgendaItemDraft(title: $title, starts: $startsAt, ends: $endsAt, notes: $notes)';
}
