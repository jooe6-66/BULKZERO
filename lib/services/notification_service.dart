import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _reminders = [
    (id: 101, hour: 8, minute: 0, title: 'Waktunya Makan 1 🍳', body: 'Jangan lewatkan sarapan berprotein tinggi untuk bulking!'),
    (id: 102, hour: 13, minute: 0, title: 'Waktunya Makan 2 🍛', body: 'Isi ulang kalori dan protein siangmu sekarang.'),
    (id: 103, hour: 16, minute: 30, title: 'Waktunya Camilan 🍌', body: 'Tambahkan camilan sehat agar target kalori harian tercapai.'),
    (id: 104, hour: 19, minute: 30, title: 'Waktunya Makan 3 🍗', body: 'Makan malam bergizi untuk pemulihan otot optimal.'),
  ];

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
          linux: linuxSettings,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init skipped: $e');
    }
  }

  static Future<bool> setDailyReminders(bool enabled) async {
    await init();
    if (!_initialized) return false;

    try {
      await _plugin.cancelAll();
      if (!enabled) return true;

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'bulking_meal_reminders',
          'Pengingat Makan Bulking',
          channelDescription: 'Pengingat jadwal makan harian untuk target bulking',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      final now = DateTime.now();
      for (final r in _reminders) {
        var target = DateTime(now.year, now.month, now.day, r.hour, r.minute);
        if (!target.isAfter(now)) {
          target = target.add(const Duration(days: 1));
        }
        final scheduled = tz.TZDateTime.from(target.toUtc(), tz.UTC);
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Failed to schedule reminders: $e');
      return false;
    }
  }
}
