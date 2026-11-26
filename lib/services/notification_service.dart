import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_settings.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  static NotificationDetails _details() {
    final key = AppSettings.sound;
    final label = AppSettings.adhanSounds[key];
    if (label != null) {
      // لكل مؤذن قناة إشعارات مستقلة، لأن صوت القناة في الأندرويد ما بيتغيّرش
      // بعد إنشائها (v2: قنوات جديدة بعد إصلاح مشكلة الصوت الصامت)
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_adhan_${key}_v2',
          'أذان - $label',
          channelDescription: 'تنبيه بصوت الأذان عند دخول وقت الصلاة',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('adhan_$key'),
        ),
      );
    }
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_times_v1',
        'مواقيت الصلاة',
        channelDescription: 'تنبيه عند دخول وقت كل صلاة',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

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

  static Future<void> _schedule(int id, String title, String body,
      tz.TZDateTime when, NotificationDetails details) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // لو الأندرويد رفض التوقيت الدقيق، نستخدم توقيت تقريبي
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// يجدول إشعارات الصلوات للأيام السبعة القادمة حسب الإعدادات.
  static Future<void> schedulePrayers(Coordinates coords) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final params = AppSettings.params();
      final details = _details();
      final now = DateTime.now();

      for (var d = 0; d < 7; d++) {
        final date = now.add(Duration(days: d));
        final t = PrayerTimes(coords, DateComponents.from(date), params);
        final times = [t.fajr, t.dhuhr, t.asr, t.maghrib, t.isha];

        for (var i = 0; i < times.length; i++) {
          if (!AppSettings.alerts[i]) continue;
          final when = times[i];
          if (!when.isAfter(now)) continue;
          await _schedule(
            d * 10 + i,
            'حان الآن وقت صلاة ${_names[i]}',
            'حيّ على الصلاة',
            tz.TZDateTime.from(when, tz.UTC),
            details,
          );
        }
      }
    } catch (_) {
      // الإشعارات ميزة إضافية، فلا نوقف التطبيق لو فشلت
    }
  }

  /// إشعار تجريبي بعد 10 ثواني بالصوت المختار.
  static Future<bool> scheduleTest() async {
    if (!_ready) return false;
    try {
      final when =
          tz.TZDateTime.now(tz.UTC).add(const Duration(seconds: 10));
      await _schedule(
        9999,
        'تجربة الإشعار',
        'لو شفت الإشعار ده يبقى الإشعارات شغالة ✓',
        when,
        _details(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// إشعار فوري بالصوت المختار (للمعاينة).
  static Future<bool> showNow() async {
    if (!_ready) return false;
    try {
      await _plugin.show(
        9998,
        'معاينة الصوت',
        'ده صوت التنبيه الحالي',
        _details(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
