import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static final _cairo = Coordinates(30.0444, 31.2357);

  double? _qibla;
  bool _usingDefault = false;

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
    final coords = await _locate();
    final direction = Qibla(coords).direction;
    if (!mounted) return;
    setState(() => _qibla = direction);
  }

  @override
  Widget build(BuildContext context) {
    if (_qibla == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر قراءة البوصلة'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final heading = snapshot.data?.heading;
        if (heading == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'جهازك لا يحتوي على حساس البوصلة، فلا يمكن عرض القبلة.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // الفرق بين اتجاه القبلة واتجاه الموبايل، من -180 إلى 180
        final diff = ((_qibla! - heading + 540) % 360) - 180;
        final aligned = diff.abs() < 3;
        final color = aligned ? Colors.green : scheme.primary;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_usingDefault)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('تعذر تحديد موقعك، الحساب مبني على القاهرة.'),
                ),
              Text(
                aligned ? 'أنت في اتجاه القبلة ✓' : 'لف الموبايل ناحية السهم',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 24),
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 4),
                ),
                child: Transform.rotate(
                  angle: diff * 3.141592653589793 / 180,
                  child: Icon(Icons.navigation, size: 160, color: color),
                ),
              ),
              const SizedBox(height: 24),
              Text('زاوية القبلة: ${_qibla!.round()}° من الشمال'),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'امسك الموبايل أفقياً وبعيداً عن المعادن. لو السهم مش ثابت '
                  'حرّك الموبايل على شكل رقم 8 لمعايرة البوصلة.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
