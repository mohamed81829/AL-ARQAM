import 'package:flutter/material.dart';

import '../data/quran_repository.dart';

class SurahReaderScreen extends StatefulWidget {
  final int chapterId;
  final int initialVerse;

  const SurahReaderScreen({
    super.key,
    required this.chapterId,
    this.initialVerse = 1,
  });

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  late final Chapter _chapter;
  late final List<VerseItem> _verses;
  late final List<GlobalKey> _keys;
  double _fontSize = 28;
  int? _marked;

  @override
  void initState() {
    super.initState();
    _chapter = QuranRepository.chapters
        .firstWhere((c) => c.id == widget.chapterId);
    _verses = QuranRepository.verses(widget.chapterId);
    _keys = List.generate(_verses.length, (_) => GlobalKey());
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final size = await QuranRepository.fontSize();
    final last = await QuranRepository.lastRead();
    if (!mounted) return;
    setState(() {
      _fontSize = size;
      if (last != null && last.$1 == widget.chapterId) _marked = last.$2;
    });
    if (widget.initialVerse > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTo(widget.initialVerse);
      });
    }
  }

  void _scrollTo(int verse) {
    if (verse < 1 || verse > _keys.length) return;
    final ctx = _keys[verse - 1].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.1,
      duration: Duration.zero,
    );
  }

  void _changeSize(double delta) {
    final next = (_fontSize + delta).clamp(20.0, 48.0).toDouble();
    setState(() => _fontSize = next);
    QuranRepository.saveFontSize(next);
  }

  void _mark(int number) {
    setState(() => _marked = number);
    QuranRepository.saveLastRead(widget.chapterId, number);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('تم حفظ مكان القراءة'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  String _arabicDigits(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  Widget _verseTile(int i) {
    final scheme = Theme.of(context).colorScheme;
    final v = _verses[i];
    final text = i == 0
        ? QuranRepository.stripBismillah(_chapter.id, v.text)
        : v.text;
    final marked = _marked == v.number;

    return InkWell(
      key: _keys[i],
      borderRadius: BorderRadius.circular(8),
      onTap: () => _mark(v.number),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: marked ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text),
              TextSpan(
                text: ' ﴿${_arabicDigits(v.number)}﴾ ',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: _fontSize * 0.8,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.justify,
          style: TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: _fontSize,
            height: 2.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBismillah = _chapter.id != 1 && _chapter.id != 9;

    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${_chapter.name}'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تصغير الخط',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _changeSize(-2),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            icon: const Icon(Icons.text_increase),
            onPressed: () => _changeSize(2),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'سورة ${_chapter.name}',
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: _fontSize + 6,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (showBismillah)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    QuranRepository.bismillah,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: _fontSize,
                      height: 2.0,
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'اضغط على أي آية لحفظ مكان القراءة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            for (var i = 0; i < _verses.length; i++) _verseTile(i),
            const SizedBox(height: 16),
            const Text(
              'نص المصحف (الرسم العثماني) من مشروع تنزيل - tanzil.net',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
