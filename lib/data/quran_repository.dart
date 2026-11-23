import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class Chapter {
  final int id;
  final String name;
  final String transliteration;
  final String type;
  final int totalVerses;

  const Chapter({
    required this.id,
    required this.name,
    required this.transliteration,
    required this.type,
    required this.totalVerses,
  });

  bool get isMeccan => type == 'meccan';
}

class VerseItem {
  final int number;
  final String text;
  const VerseItem(this.number, this.text);
}

Map<String, dynamic> _decodeJson(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

class QuranRepository {
  static List<Chapter> _chapters = [];
  static Map<String, dynamic> _text = {};
  static String bismillah = '';
  static bool _loaded = false;

  static List<Chapter> get chapters => _chapters;

  static Future<void> load() async {
    if (_loaded) return;
    final chaptersRaw =
        await rootBundle.loadString('assets/quran/chapters.json');
    final textRaw = await rootBundle.loadString('assets/quran/uthmani.json');
    final chaptersJson = await compute(_decodeJson, chaptersRaw);
    final textJson = await compute(_decodeJson, textRaw);

    final list = chaptersJson['chapters'] as List<dynamic>;
    _chapters = [
      for (final c in list)
        Chapter(
          id: c['id'] as int,
          name: c['name'] as String,
          transliteration: c['transliteration'] as String,
          type: c['type'] as String,
          totalVerses: c['total_verses'] as int,
        ),
    ];
    _text = textJson;
    final fatiha = _text['1'] as List<dynamic>;
    bismillah = fatiha[0]['text'] as String;
    _loaded = true;
  }

  static List<VerseItem> verses(int chapter) {
    final raw = _text[chapter.toString()] as List<dynamic>;
    return [
      for (final v in raw) VerseItem(v['verse'] as int, v['text'] as String),
    ];
  }

  /// في ملف تنزيل البسملة ملصوقة بأول آية في كل سورة (ما عدا الفاتحة والتوبة).
  /// هنا بنعرضها في عنوان السورة ونعرض الآية الأولى بدونها، من غير تعديل الملف.
  static String stripBismillah(int chapter, String text) {
    if (chapter == 1 || chapter == 9) return text;
    final words = text.split(' ');
    final b = bismillah.split(' ');
    if (words.length <= b.length) return text;
    // سورتا 95 و97 فيهما اختلاف في ضبط كلمة "بسم" فقط، فنقارن باقي الكلمات
    for (var i = 1; i < b.length; i++) {
      if (words[i] != b[i]) return text;
    }
    return words.sublist(b.length).join(' ');
  }

  static Future<(int, int)?> lastRead() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getInt('quran_last_chapter');
      final v = p.getInt('quran_last_verse');
      if (c == null || v == null) return null;
      return (c, v);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastRead(int chapter, int verse) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('quran_last_chapter', chapter);
      await p.setInt('quran_last_verse', verse);
    } catch (_) {}
  }

  static Future<double> fontSize() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getDouble('quran_font_size') ?? 28.0;
    } catch (_) {
      return 28.0;
    }
  }

  static Future<void> saveFontSize(double v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('quran_font_size', v);
    } catch (_) {}
  }
}
