import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  static const _key = 'tasbeeh_count';
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _count = prefs.getInt(_key) ?? 0);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _count);
  }

  void _inc() {
    setState(() => _count++);
    HapticFeedback.lightImpact();
    _save();
  }

  void _reset() {
    setState(() => _count = 0);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_count',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 200,
            child: FilledButton(
              onPressed: _inc,
              style: FilledButton.styleFrom(shape: const CircleBorder()),
              child: const Text('سبّح', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('تصفير'),
          ),
        ],
      ),
    );
  }
}
