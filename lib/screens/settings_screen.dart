import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget _header(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _header('حساب المواقيت'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              isExpanded: true,
              value: AppSettings.method,
              items: [
                for (final e in AppSettings.methodNames.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  AppSettings.setMethod(v);
                });
              },
            ),
          ),
          SwitchListTile(
            title: const Text('العصر بالمذهب الحنفي'),
            subtitle: const Text('يدخل وقت العصر لما يبقى ظل الشيء مثليه'),
            value: AppSettings.hanafi,
            onChanged: (v) {
              setState(() {
                AppSettings.setHanafi(v);
              });
            },
          ),
          _header('تنبيهات الصلاة'),
          for (var i = 0; i < 5; i++)
            SwitchListTile(
              title: Text(AppSettings.prayerNames[i]),
              value: AppSettings.alerts[i],
              onChanged: (v) {
                setState(() {
                  AppSettings.setAlert(i, v);
                });
              },
            ),
          _header('صوت التنبيه'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'default', label: Text('صوت الموبايل')),
                ButtonSegment(value: 'adhan', label: Text('الأذان')),
              ],
              selected: {AppSettings.sound},
              onSelectionChanged: (s) {
                setState(() {
                  AppSettings.setSound(s.first);
                });
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'لتفعيل صوت الأذان: ارفع ملف صوتي باسم adhan.mp3 داخل فولدر '
              'sounds في المشروع على GitHub، وانتظر البناء الجديد.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          _header('المظهر'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('تلقائي')),
                ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
              ],
              selected: {AppSettings.themeMode.value},
              onSelectionChanged: (s) {
                setState(() {
                  AppSettings.setTheme(s.first);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
