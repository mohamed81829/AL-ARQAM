import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  static const methodNames = <String, String>{
    'egyptian': 'الهيئة المصرية العامة للمساحة',
    'umm_al_qura': 'أم القرى (مكة المكرمة)',
    'muslim_world_league': 'رابطة العالم الإسلامي',
    'karachi': 'جامعة العلوم الإسلامية - كراتشي',
    'north_america': 'أمريكا الشمالية (ISNA)',
    'kuwait': 'الكويت',
  };

  static const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  static String method = 'egyptian';
  static bool hanafi = false;
  static String sound = 'default'; // default | adhan
  static List<bool> alerts = [true, true, true, true, true];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final m = p.getString('method') ?? 'egyptian';
    method = methodNames.containsKey(m) ? m : 'egyptian';
    hanafi = p.getBool('hanafi') ?? false;
    sound = p.getString('sound') ?? 'default';
    alerts = [for (var i = 0; i < 5; i++) p.getBool('alert_$i') ?? true];
    final t = p.getString('theme') ?? 'system';
    themeMode.value = t == 'light'
        ? ThemeMode.light
        : t == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
  }

  /// إعدادات حساب المواقيت حسب اختيارك.
  static dynamic params() {
    final p = switch (method) {
      'umm_al_qura' => CalculationMethod.umm_al_qura.getParameters(),
      'muslim_world_league' =>
        CalculationMethod.muslim_world_league.getParameters(),
      'karachi' => CalculationMethod.karachi.getParameters(),
      'north_america' => CalculationMethod.north_america.getParameters(),
      'kuwait' => CalculationMethod.kuwait.getParameters(),
      _ => CalculationMethod.egyptian.getParameters(),
    };
    p.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    return p;
  }

  static Future<void> _save(
      Future<bool> Function(SharedPreferences p) action) async {
    try {
      await action(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  static void setMethod(String v) {
    method = v;
    _save((p) => p.setString('method', v));
  }

  static void setHanafi(bool v) {
    hanafi = v;
    _save((p) => p.setBool('hanafi', v));
  }

  static void setSound(String v) {
    sound = v;
    _save((p) => p.setString('sound', v));
  }

  static void setAlert(int i, bool v) {
    alerts[i] = v;
    _save((p) => p.setBool('alert_$i', v));
  }

  static void setTheme(ThemeMode m) {
    themeMode.value = m;
    final name = m == ThemeMode.light
        ? 'light'
        : m == ThemeMode.dark
            ? 'dark'
            : 'system';
    _save((p) => p.setString('theme', name));
  }
}
