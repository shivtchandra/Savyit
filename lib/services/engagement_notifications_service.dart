// lib/services/engagement_notifications_service.dart
// In-house rules: schedule a single local notification in the evening when the
// calendar day has zero transactions (SMS or manual). No server; rescheduled
// whenever data changes or after SMS scan.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/transaction.dart';
import 'storage_service.dart';

class EngagementNotificationsService {
  static const _channelId = 'engagement';
  static const _eveningId = 9001;
  static const _eveningHour = 19;
  static const _eveningMinute = 30;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Reminders',
            description: 'Nudges to keep your spending log up to date.',
            importance: Importance.defaultImportance,
          ));

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: false, sound: true);
      }

      _initialized = true;
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'EngagementNotificationsService: native plugin missing ($e). '
          'Fully stop the app and run `flutter run` once after adding '
          '`flutter_local_notifications` — hot restart does not link new plugins.',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('EngagementNotificationsService: init failed: $e\n$st');
      }
    }
  }

  /// Call after any change to persisted transactions (or after SMS scan).
  static Future<void> syncFromTransactions(List<Transaction> txns) async {
    if (kIsWeb || !_initialized) return;

    if (!await StorageService.getEngagementNotificationsEnabled()) {
      await _plugin.cancel(_eveningId);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
      if (!await Permission.notification.isGranted) {
        return;
      }
    }

    if (_countToday(txns) > 0) {
      await _plugin.cancel(_eveningId);
      return;
    }

    final when = _nextEvening(_eveningHour, _eveningMinute);

    try {
      await _plugin.zonedSchedule(
        _eveningId,
        'Nothing logged today',
        'No transactions for today yet — open Savyit to scan SMS or add one manually.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Reminders',
            channelDescription:
                'Nudges to keep your spending log up to date.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EngagementNotificationsService: schedule failed: $e');
      }
    }
  }

  static int _countToday(List<Transaction> txns) {
    final n = DateTime.now();
    return txns
        .where((t) =>
            t.date.year == n.year &&
            t.date.month == n.month &&
            t.date.day == n.day)
        .length;
  }

  static tz.TZDateTime _nextEvening(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
}
