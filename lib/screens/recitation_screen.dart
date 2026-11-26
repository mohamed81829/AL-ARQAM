import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../services/recitation_checker.dart';
import '../services/recitation_controller.dart';

class RecitationScreen extends StatefulWidget {
  final int chapterId;
  final int startVerse;

  const RecitationScreen({
    super.key,
    required this.chapterId,
    this.startVerse = 1,
  });

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final RecitationController _rec = RecitationController();
  final List<List<String>> _verseWords = [];
  final List<int> _verseStart = []; // رقم أول كلمة في كل آية (من كل كلمات السورة)
  final List<int> _wordVerse = []; // رقم الآية (من صفر) لكل كلمة
  final List<String> _allWords = [];
  final List<GlobalKey> _keys = [];
  late final Chapter _chapter;
  late final List<VerseItem> _verses;

  int _fromVerse = 1; // الآية اللي هتبدأ منها (من 1)
  int _offset = 0; // رقم أول كلمة اتبعتت للمحرك
  bool _hide = true;
  bool _started = false;
  int _lastShownVerse = -1;

  @override
  void initState() {
    super.initState();
    _chapter = QuranRepository.chapters
        .firstWhere((c) => c.id == widget.chapterId);
    _verses = QuranRepository.verses(widget.chapterId);
    for (var i = 0; i < _verses.length; i++) {
      final raw = i == 0
          ? QuranRepository.stripBismillah(_chapter.id, _verses[i].text)
          : _verses[i].text;
      final ws = raw
          .split(' ')
          .where((w) => WordCheck.normalize(w).isNotEmpty)
          .toList();
      _verseWords.add(ws);
      _verseStart.add(_allWords.length);
      for (final w in ws) {
        _allWords.add(w);
        _wordVerse.add(i);
      }
      _keys.add(GlobalKey());
    }
    final s = widget.startVerse;
    _fromVerse = s < 1 ? 1 : (s > _verses.length ? _verses.length : s);
    _rec.addListener(_onRec);
  }

  @override
  void dispose() {
    _rec.removeListener(_onRec);
    _rec.dispose();
    super.dispose();
  }

  /// رقم الكلمة المتوقعة الجاية (من كل كلمات السورة).
  int get _confirmedGlobal => _offset + _rec.confirmed;

  int get _currentVerseIndex {
    final c = _confirmedGlobal;
    if (c >= _allWords.length) return _verses.length - 1;
    return _wordVerse[c];
  }

  void _onRec() {
    if (!mounted) return;
    setState(() {});
    final v = _currentVerseIndex;
    if (_started && v != _lastShownVerse) {
      _lastShownVerse = v;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[v].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    }
  }

  Future<void> _begin(int verseIndex) async {
    _offset = _verseStart[verseIndex];
    _lastShownVerse = -1;
    setState(() => _started = true);
    await _rec.start(_allWords.sublist(_offset).join(' '));
  }

  Future<void> _stopAndRemember() async {
    final vi = _currentVerseIndex;
    await _rec.stop();
    if (!mounted) return;
    setState(() {
      _fromVerse = vi + 1;
      _started = false;
    });
  }

  void _retryCurrent() {
    final m = _rec.mistakeIndex;
    final g = m == null ? _confirmedGlobal : _offset + m;
    final vi = g >= _allWords.length ? _verses.length - 1 : _wordVerse[g];
    _begin(vi);
  }

  String _arabicDigits(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  String _statusText() {
    final state = _rec.state;
    final m = _rec.mistakeIndex;
    final gi = m == null ? null : _offset + m;
    final where = (gi == null || gi >= _allWords.length)
        ? ''
        : ' في الآية ${_wordVerse[gi] + 1}';

    if (state == RecitationState.listening) {
      return 'جاري الاستماع... أنت في الآية ${_currentVerseIndex + 1}';
    }
    if (state == RecitationState.wrong) {
      final h = _rec.heard;
      return (h == null || h.isEmpty)
          ? 'أخطأت ✗$where — الكلمة الصحيحة بالأحمر'
          : 'أخطأت ✗$where — سمعتك تقول "$h" والصح بالأحمر';
    }
    if (state == RecitationState.missed) {
      return 'حسبك ✋ نسيت كلمة$where — الكلمة الصحيحة بالأحمر';
    }
    if (state == RecitationState.stuck) {
      return 'حسبك ✋ توقفت$where — الكلمة الجاية بالأحمر';
    }
    if (state == RecitationState.complete) {
      return 'أحسنت ✓ أتممت التسميع لآخر السورة';
    }
    if (state == RecitationState.error) {
      return _rec.errorText ?? 'حصل خطأ';
    }
    return 'اختر الآية التي تبدأ منها، واضغط "ابدأ التسميع"';
  }

  Color? _statusColor() {
    final state = _rec.state;
    if (state == RecitationState.wrong ||
        state == RecitationState.missed ||
        state == RecitationState.stuck ||
        state == RecitationState.error) {
      return Colors.red.shade700;
    }
    if (state == RecitationState.complete) return Colors.green.shade700;
    return null;
  }

  Widget _mainButton() {
    final state = _rec.state;
    if (state == RecitationState.listening) {
      return FilledButton.icon(
        onPressed: _stopAndRemember,
        icon: const Icon(Icons.stop),
        label: const Text('إيقاف'),
      );
    }
    if (state == RecitationState.wrong ||
        state == RecitationState.missed ||
        state == RecitationState.stuck) {
      return FilledButton.icon(
        onPressed: _retryCurrent,
        icon: const Icon(Icons.replay),
        label: const Text('أعد الآية'),
      );
    }
    return FilledButton.icon(
      onPressed: () => _begin(_fromVerse - 1),
      icon: const Icon(Icons.mic),
      label: Text(
        state == RecitationState.complete ? 'ابدأ من جديد' : 'ابدأ التسميع',
      ),
    );
  }

  Widget _verseTile(int i) {
    final scheme = Theme.of(context).colorScheme;
    final dim = Theme.of(context).disabledColor;
    final words = _verseWords[i];
    final start = _verseStart[i];
    final end = start + words.length;
    final c = _confirmedGlobal;
    final m = _rec.mistakeIndex;
    final failIdx = m == null ? null : _offset + m;
    final active = _started && _rec.state != RecitationState.idle;
    final isCurrent = active && i == _currentVerseIndex;

    TextStyle style(Color? color, {Color? bg}) => TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 28,
          height: 2.0,
          color: color,
          backgroundColor: bg,
        );

    final spans = <InlineSpan>[];

    if (active && c >= end) {
      // آية اتسمّعت كاملة
      spans.add(TextSpan(
        text: words.join(' '),
        style: style(Colors.green.shade700),
      ));
    } else if (active && c >= start) {
      // الآية الحالية
      if (c > start) {
        spans.add(TextSpan(
          text: '${words.sublist(0, c - start).join(' ')} ',
          style: style(Colors.green.shade700),
        ));
      }
      if (failIdx != null && failIdx >= start && failIdx < end) {
        spans.add(TextSpan(
          text: words[failIdx - start],
          style: style(Colors.red.shade900, bg: Colors.red.shade100),
        ));
        final restStart = failIdx - start + 1;
        if (restStart < words.length) {
          spans.add(TextSpan(
            text: _hide ? ' …' : ' ${words.sublist(restStart).join(' ')}',
            style: style(dim),
          ));
        }
      } else {
        final rest = words.sublist(c - start);
        spans.add(TextSpan(
          text: _hide ? '…' : rest.join(' '),
          style: style(dim),
        ));
      }
    } else {
      // آية لسه ما جاش دورها (أو قبل نقطة البداية)
      spans.add(TextSpan(
        text: _hide ? '• • • • •' : words.join(' '),
        style: style(_hide ? dim : null),
      ));
    }

    spans.add(TextSpan(
      text: ' ﴿${_arabicDigits(i + 1)}﴾',
      style: TextStyle(color: scheme.primary, fontSize: 22),
    ));

    return Container(
      key: _keys[i],
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrent ? scheme.secondaryContainer : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listening = _rec.isListening;

    return Scaffold(
      appBar: AppBar(
        title: Text('تسميع سورة ${_chapter.name}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Text('ابدأ من الآية'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _fromVerse,
                    items: [
                      for (var n = 1; n <= _verses.length; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: listening
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _fromVerse = v;
                              _started = false;
                            });
                            _rec.stop();
                          },
                  ),
                  const Spacer(),
                  const Text('إخفاء الآيات'),
                  Switch(
                    value: _hide,
                    onChanged: (v) => setState(() => _hide = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    for (var i = 0; i < _verses.length; i++) _verseTile(i),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                _statusText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _statusColor(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _mainButton(),
            ),
          ],
        ),
      ),
    );
  }
}
