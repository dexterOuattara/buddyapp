import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../db/app_database.dart';

/// Schedules device-local notifications from the offline Agenda database.
/// A rolling one-year window keeps weekly series bounded and is refreshed
/// whenever Agenda data changes or the app starts.
class AgendaReminderService {
  AgendaReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    if (!_supported) {
      _initialized = true;
      return;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_supported) return true;
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios ?? true;
  }

  Future<void> reconcile(Iterable<AgendaItem> items) async {
    await initialize();
    if (!_supported) return;
    for (final item in items) {
      await schedule(item);
    }
  }

  Future<void> schedule(AgendaItem item) async {
    await initialize();
    if (!_supported) return;
    await cancel(item.clientUuid);
    final startsAt = item.startsAt;
    final reminder = item.reminderMinutes;
    if (item.deleted || startsAt == null || reminder == null) return;

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 366));
    final lastDate = item.recurrenceUntil == null
        ? horizon
        : (item.recurrenceUntil!.toLocal().isBefore(horizon)
              ? DateTime(
                  item.recurrenceUntil!.toLocal().year,
                  item.recurrenceUntil!.toLocal().month,
                  item.recurrenceUntil!.toLocal().day,
                  23,
                  59,
                  59,
                )
              : horizon);
    var occurrence = startsAt.toLocal();
    if (item.recurrence == 'weekly') {
      while (occurrence.subtract(Duration(minutes: reminder)).isBefore(now)) {
        occurrence = occurrence.add(const Duration(days: 7));
      }
    }
    var index = 0;
    while (index < 52 && !occurrence.isAfter(lastDate)) {
      final trigger = occurrence.subtract(Duration(minutes: reminder));
      if (trigger.isAfter(now)) {
        await _plugin.zonedSchedule(
          _notificationId(item.clientUuid, index),
          reminder == 0
              ? item.title
              : '${item.title} dans ${_durationLabel(reminder)}',
          [
            item.subject,
            item.location,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
          tz.TZDateTime.from(trigger.toUtc(), tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'agenda_reminders',
              'Rappels de l’agenda',
              channelDescription: 'Cours, révisions et rappels planifiés',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: item.clientUuid,
        );
      }
      if (item.recurrence != 'weekly') break;
      occurrence = occurrence.add(const Duration(days: 7));
      index++;
    }
  }

  Future<void> cancel(String clientUuid) async {
    await initialize();
    if (!_supported) return;
    for (var index = 0; index < 52; index++) {
      await _plugin.cancel(_notificationId(clientUuid, index));
    }
  }

  int _notificationId(String clientUuid, int occurrence) {
    var hash = 0x811C9DC5;
    for (final codeUnit in clientUuid.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return (hash % 40000000) * 52 + math.min(occurrence, 51);
  }

  String _durationLabel(int minutes) {
    if (minutes == 60) return '1 heure';
    return '$minutes minutes';
  }
}
