import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// يجدول إشعارات الصلوات الخمس للأيام السبعة القادمة.
  static Future<void> schedulePrayers(Coordinates coords) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final params = CalculationMethod.egyptian.getParameters();
      final now = DateTime.now();

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_times_v1',
          'مواقيت الصلاة',
          channelDescription: 'تنبيه عند دخول وقت كل صلاة',
          importance: Importance.max,
          priority: Priority.high,
        ),
      );

      for (var d = 0; d < 7; d++) {
        final date = now.add(Duration(days: d));
        final t = PrayerTimes(coords, DateComponents.from(date), params);
        final times = [t.fajr, t.dhuhr, t.asr, t.maghrib, t.isha];

        for (var i = 0; i < times.length; i++) {
          final when = times[i];
          if (!when.isAfter(now)) continue;
          final scheduled = tz.TZDateTime.from(when, tz.UTC);
          final id = d * 10 + i;
          final title = 'حان الآن وقت صلاة ${_names[i]}';
          const body = 'حيّ على الصلاة';

          try {
            await _plugin.zonedSchedule(
              id,
              title,
              body,
              scheduled,
              details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            );
          } catch (_) {
            // لو الأندرويد رفض التوقيت الدقيق، نستخدم توقيت تقريبي
            await _plugin.zonedSchedule(
              id,
              title,
              body,
              scheduled,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
        }
      }
    } catch (_) {
      // الإشعارات ميزة إضافية، فلا نوقف التطبيق لو فشلت
    }
  }
}
