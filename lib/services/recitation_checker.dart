/// أدوات مقارنة الكلام المسموع بنص الآية.
class WordCheck {
  static bool _isMark(int r) =>
      (r >= 0x0610 && r <= 0x061A) ||
      (r >= 0x064B && r <= 0x065F) ||
      r == 0x0670 ||
      (r >= 0x06D6 && r <= 0x06ED) ||
      (r >= 0x08D3 && r <= 0x08FF) ||
      r == 0x0640 ||
      r == 0x200C ||
      r == 0x200D;

  static const Map<int, String> _map = {
    0x0671: 'ا',
    0x0623: 'ا',
    0x0625: 'ا',
    0x0622: 'ا',
    0x0649: 'ي',
    0x0629: 'ه',
    0x0624: 'و',
    0x0626: 'ي',
    0x06A9: 'ك',
    0x06CC: 'ي',
  };

  /// بيشيل التشكيل والعلامات، ويوحّد الأشكال، ويشيل الألف،
  /// عشان الرسم العثماني والإملائي يتطابقوا.
  static String normalize(String word) {
    final sb = StringBuffer();
    for (final r in word.runes) {
      if (_isMark(r) || r == 0x0621) continue;
      final ch = _map[r] ?? String.fromCharCode(r);
      final code = ch.runes.first;
      if (code < 0x0621 || code > 0x064A) continue;
      sb.write(ch);
    }
    final s = sb.toString();
    final skeleton = s.replaceAll('ا', '');
    return skeleton.isEmpty ? s : skeleton;
  }

  static bool similar(String a, String b) {
    if (a == b) return true;
    final m = a.length < b.length ? a.length : b.length;
    final limit = m >= 8 ? 2 : (m >= 4 ? 1 : 0);
    if (limit == 0) return false;
    if ((a.length - b.length).abs() > limit) return false;
    return _distance(a, b) <= limit;
  }

  static int _distance(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var best = prev[j] + 1;
        if (cur[j - 1] + 1 < best) best = cur[j - 1] + 1;
        if (prev[j - 1] + cost < best) best = prev[j - 1] + cost;
        cur[j] = best;
      }
      prev = cur;
    }
    return prev[b.length];
  }
}

class RecitationResult {
  final int confirmed; // عدد الكلمات الصحيحة المؤكدة
  final int? mistakeIndex; // رقم الكلمة اللي فيها المشكلة
  final bool missed; // true لو نسي كلمة (قال اللي بعدها)
  final String? heard; // الكلمة اللي اتسمعت
  final bool pending; // لسه مش متأكدين (آخر كلمة بتتكوّن)
  final bool complete;

  const RecitationResult({
    required this.confirmed,
    this.mistakeIndex,
    this.missed = false,
    this.heard,
    this.pending = false,
    this.complete = false,
  });
}

class RecitationChecker {
  final List<String> expected;

  RecitationChecker(List<String> words)
      : expected = [for (final w in words) WordCheck.normalize(w)];

  /// بيقارن الكلام المسموع بالمتوقع بداية من كلمة [baseIndex].
  RecitationResult evaluate(
    int baseIndex,
    List<String> heardWords, {
    required bool isFinal,
  }) {
    var idx = baseIndex;
    var i = 0;
    while (i < heardWords.length) {
      if (idx >= expected.length) break;
      final w = WordCheck.normalize(heardWords[i]);
      if (w.isEmpty) {
        i++;
        continue;
      }
      final isLast = i == heardWords.length - 1;

      // 1) تطابق مباشر
      if (WordCheck.similar(w, expected[idx])) {
        idx++;
        i++;
        continue;
      }

      // 2) المحرك دمج كلمتين في كلمة
      if (idx + 1 < expected.length &&
          WordCheck.similar(w, expected[idx] + expected[idx + 1])) {
        idx += 2;
        i++;
        continue;
      }

      // 3) المحرك قسّم الكلمة لجزئين
      if (!isLast) {
        final n = WordCheck.normalize(heardWords[i + 1]);
        if (n.isNotEmpty && WordCheck.similar(w + n, expected[idx])) {
          idx++;
          i += 2;
          continue;
        }
      }

      // 4) المسموع مش مطابق: نسي كلمة ولا قال كلمة غلط؟
      final missed = idx + 1 < expected.length &&
          WordCheck.similar(w, expected[idx + 1]);

      if (isLast && !isFinal) {
        return RecitationResult(
          confirmed: idx,
          mistakeIndex: idx,
          missed: missed,
          heard: heardWords[i],
          pending: true,
        );
      }
      return RecitationResult(
        confirmed: idx,
        mistakeIndex: idx,
        missed: missed,
        heard: heardWords[i],
      );
    }
    return RecitationResult(
      confirmed: idx,
      complete: idx >= expected.length,
    );
  }
}
