import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/app_settings.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((s) {
      final playing =
          s.playing && s.processingState != ProcessingState.completed;
      if (mounted && playing != _playing) {
        setState(() => _playing = playing);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _preview(String key) async {
    try {
      await _player.stop();
      if (key == 'default') {
        final ok = await NotificationService.showNow();
        if (!ok && mounted) {
          _snack('الإشعارات غير مفعّلة. تأكد من السماح بها في إعدادات الموبايل.');
        }
        return;
      }
      await _player.setAsset('assets/adhan/adhan_$key.mp3');
      unawaited(_player.play());
    } catch (_) {
      if (mounted) _snack('تعذر تشغيل المعاينة.');
    }
  }

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
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: AppSettings.sound,
                    items: [
                      const DropdownMenuItem(
                        value: 'default',
                        child: Text('صوت الموبايل العادي'),
                      ),
                      for (final e in AppSettings.adhanSounds.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        AppSettings.setSound(v);
                      });
                      _preview(v);
                    },
                  ),
                ),
                IconButton(
                  tooltip: _playing ? 'إيقاف' : 'معاينة',
                  iconSize: 32,
                  icon: Icon(
                    _playing
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  onPressed: () {
                    if (_playing) {
                      _player.stop();
                    } else {
                      _preview(AppSettings.sound);
                    }
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'اختيار الصوت بيشغّله للمعاينة. واضغط ▶ لإعادته أو ⏹ لإيقافه.',
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
