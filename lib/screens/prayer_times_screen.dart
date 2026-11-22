import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/notification_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  // القاهرة كموقع افتراضي لو الإذن مرفوض
  static final _cairo = Coordinates(30.0444, 31.2357);

  PrayerTimes? _times;
  bool _usingDefault = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Coordinates> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _usingDefault = true;
        return _cairo;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _usingDefault = true;
        return _cairo;
      }
      final pos = await Geolocator.getCurrentPosition();
      return Coordinates(pos.latitude, pos.longitude);
    } catch (_) {
      _usingDefault = true;
      return _cairo;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _usingDefault = false;
    final coords = await _locate();
    // نجدول الإشعارات بس لو موقعك الحقيقي متاح
    if (!_usingDefault) NotificationService.schedulePrayers(coords);
    final params = CalculationMethod.egyptian.getParameters();
    final times = PrayerTimes.today(coords, params);
    if (!mounted) return;
    setState(() {
      _times = times;
      _loading = false;
    });
  }

  String _fmt(DateTime t) {
    final l = t.toLocal();
    final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '$h12:$m ${l.hour < 12 ? 'ص' : 'م'}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _times == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = _times!;
    final rows = <(String, DateTime, IconData)>[
      ('الفجر', t.fajr, Icons.nights_stay),
      ('الشروق', t.sunrise, Icons.wb_twilight),
      ('الظهر', t.dhuhr, Icons.wb_sunny),
      ('العصر', t.asr, Icons.wb_cloudy),
      ('المغرب', t.maghrib, Icons.wb_twilight),
      ('العشاء', t.isha, Icons.dark_mode),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_usingDefault)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'تعذر تحديد موقعك، فالمواقيت معروضة للقاهرة. '
                  'فعّل الموقع واسحب للتحديث.',
                ),
              ),
            ),
          for (final r in rows)
            Card(
              child: ListTile(
                leading: Icon(r.$3),
                title: Text(r.$1, style: const TextStyle(fontSize: 20)),
                trailing: Text(_fmt(r.$2),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
