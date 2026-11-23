import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VerseRef {
  final int chapter;
  final int verse;
  const VerseRef(this.chapter, this.verse);
}

class HifzPlan {
  final int chapter;
  final int nextVerse; // أول آية لسه ما اتحفظتش
  final int dailyNew;

  const HifzPlan({
    required this.chapter,
    required this.nextVerse,
    required this.dailyNew,
  });

  HifzPlan copyWith({int? nextVerse}) => HifzPlan(
        chapter: chapter,
        nextVerse: nextVerse ?? this.nextVerse,
        dailyNew: dailyNew,
      );

  Map<String, dynamic> toJson() => {
        'chapter': chapter,
        'nextVerse': nextVerse,
        'dailyNew': dailyNew,
      };

  static HifzPlan fromJson(Map<String, dynamic> j) => HifzPlan(
        chapter: j['chapter'] as int,
        nextVerse: j['nextVerse'] as int,
        dailyNew: j['dailyNew'] as int,
      );
}

class ReviewItem {
  final int chapter;
  final int verse;
  int level;
  String due; // yyyy-MM-dd

  ReviewItem(this.chapter, this.verse, this.level, this.due);

  String get key => '$chapter:$verse';

  List<dynamic> toJson() => [chapter, verse, level, due];

  static ReviewItem fromJson(List<dynamic> j) =>
      ReviewItem(j[0] as int, j[1] as int, j[2] as int, j[3] as String);
}

class HifzStore {
  HifzStore._();
  static final HifzStore instance = HifzStore._();

  // فترات المراجعة بالأيام حسب مستوى الآية
  static const _intervals = [1, 3, 7, 14, 30, 60];

  HifzPlan? plan;
  final Map<String, ReviewItem> _reviews = {};
  String lastNewDate = '';
  int streak = 0;
  String streakDate = '';
  bool _loaded = false;

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get today => ymd(DateTime.now());

  Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      final planRaw = p.getString('hifz_plan');
      if (planRaw != null) {
        plan = HifzPlan.fromJson(jsonDecode(planRaw) as Map<String, dynamic>);
      }
      final revRaw = p.getString('hifz_reviews');
      if (revRaw != null) {
        for (final e in jsonDecode(revRaw) as List<dynamic>) {
          final r = ReviewItem.fromJson(e as List<dynamic>);
          _reviews[r.key] = r;
        }
      }
      lastNewDate = p.getString('hifz_last_new') ?? '';
      streak = p.getInt('hifz_streak') ?? 0;
      streakDate = p.getString('hifz_streak_date') ?? '';
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final current = plan;
      if (current != null) {
        await p.setString('hifz_plan', jsonEncode(current.toJson()));
      }
      await p.setString(
        'hifz_reviews',
        jsonEncode([for (final r in _reviews.values) r.toJson()]),
      );
      await p.setString('hifz_last_new', lastNewDate);
      await p.setInt('hifz_streak', streak);
      await p.setString('hifz_streak_date', streakDate);
    } catch (_) {}
  }

  int get memorizedCount => _reviews.length;

  ReviewItem? reviewOf(int chapter, int verse) => _reviews['$chapter:$verse'];

  Future<void> setPlan(int chapter, int startVerse, int dailyNew) async {
    plan = HifzPlan(
      chapter: chapter,
      nextVerse: startVerse,
      dailyNew: dailyNew,
    );
    await _save();
  }

  /// آيات الحفظ الجديد المطلوبة النهاردة (فاضية لو خلّصتها أو السورة خلصت).
  List<int> todayNewVerses(int totalVerses) {
    final p = plan;
    if (p == null || lastNewDate == today) return [];
    if (p.nextVerse > totalVerses) return [];
    final last = p.nextVerse + p.dailyNew - 1;
    final end = last > totalVerses ? totalVerses : last;
    return [for (var v = p.nextVerse; v <= end; v++) v];
  }

  /// الآيات المستحقة للمراجعة النهاردة.
  List<ReviewItem> dueReviews() {
    final t = today;
    final list = _reviews.values.where((r) => r.due.compareTo(t) <= 0).toList();
    list.sort((a, b) => a.chapter != b.chapter
        ? a.chapter.compareTo(b.chapter)
        : a.verse.compareTo(b.verse));
    return list;
  }

  Future<void> markMemorized(int chapter, int verse) async {
    final tomorrow = ymd(DateTime.now().add(const Duration(days: 1)));
    final r = ReviewItem(chapter, verse, 0, tomorrow);
    _reviews[r.key] = r;
    final p = plan;
    if (p != null && p.chapter == chapter && verse >= p.nextVerse) {
      plan = p.copyWith(nextVerse: verse + 1);
    }
    await _save();
  }

  Future<void> finishNewSession() async {
    lastNewDate = today;
    await _save();
  }

  Future<void> rateReview(ReviewItem item, bool remembered) async {
    if (remembered) {
      final next = item.level + 1;
      item.level = next > _intervals.length - 1 ? _intervals.length - 1 : next;
    } else {
      item.level = 0;
    }
    final due = DateTime.now().add(Duration(days: _intervals[item.level]));
    item.due = ymd(due);
    await _save();
  }

  Future<void> updateStreak(bool allDone) async {
    if (!allDone || streakDate == today) return;
    final yesterday = ymd(DateTime.now().subtract(const Duration(days: 1)));
    streak = streakDate == yesterday ? streak + 1 : 1;
    streakDate = today;
    await _save();
  }

  int get currentStreak {
    final yesterday = ymd(DateTime.now().subtract(const Duration(days: 1)));
    return (streakDate == today || streakDate == yesterday) ? streak : 0;
  }
}
