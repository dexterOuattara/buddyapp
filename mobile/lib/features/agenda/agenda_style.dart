import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../db/app_database.dart';

class AgendaKindStyle {
  const AgendaKindStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

AgendaKindStyle agendaKindStyle(String kind) => switch (kind) {
  'revision' => const AgendaKindStyle(
    label: 'Révision',
    icon: Icons.menu_book_rounded,
    color: AppColors.secondary,
    softColor: Color(0xFFE5F0FF),
  ),
  'reminder' => const AgendaKindStyle(
    label: 'Rappel',
    icon: Icons.notifications_none_rounded,
    color: AppColors.warning,
    softColor: Color(0xFFFFF3D6),
  ),
  _ => const AgendaKindStyle(
    label: 'Cours',
    icon: Icons.functions_rounded,
    color: AppColors.secondary,
    softColor: Color(0xFFE5F0FF),
  ),
};

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime value) =>
    DateTime(value.toLocal().year, value.toLocal().month, value.toLocal().day);

bool agendaItemOccursOn(AgendaItem item, DateTime date) {
  final start = item.startsAt;
  if (start == null || item.deleted) return false;
  final target = dateOnly(date);
  final first = dateOnly(start);
  if (item.recurrence != 'weekly') return isSameDay(first, target);
  if (target.isBefore(first) || target.weekday != first.weekday) return false;
  final until = item.recurrenceUntil;
  return until == null || !target.isAfter(dateOnly(until));
}

const _shortDays = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const _longDays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String shortWeekday(DateTime date) => _shortDays[date.weekday - 1];

String longFrenchDate(DateTime date, {bool includeYear = false}) {
  final local = date.toLocal();
  final suffix = includeYear ? ' ${local.year}' : '';
  return '${_longDays[local.weekday - 1]} ${local.day} '
      '${_months[local.month - 1]}$suffix';
}

String agendaTime(DateTime? date) =>
    date == null ? '—' : DateFormat('HH:mm').format(date.toLocal());

String reminderLabel(int? minutes) => switch (minutes) {
  null => 'Aucun rappel',
  60 => '1 h avant',
  final value => '$value min avant',
};
