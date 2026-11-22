import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/azkar_screen.dart';
import 'screens/prayer_times_screen.dart';
import 'screens/qibla_screen.dart';
import 'services/notification_service.dart';
import 'screens/tasbeeh_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const AlArqamApp());
}

class AlArqamApp extends StatelessWidget {
  const AlArqamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الأرقم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B7F5C),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B7F5C),
        brightness: Brightness.dark,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['مواقيت الصلاة', 'القبلة', 'الأذكار', 'المسبحة'];

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const PrayerTimesScreen();
      case 1:
        return const QiblaScreen();
      case 2:
        return const AzkarScreen();
      default:
        return const TasbeehScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index]), centerTitle: true),
      // الصفحة الحالية بس هي اللي بتشتغل، عشان البوصلة ما تستهلكش البطارية في الخلفية
      body: _page(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time), label: 'المواقيت'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'القبلة'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'الأذكار'),
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'المسبحة'),
        ],
      ),
    );
  }
}
