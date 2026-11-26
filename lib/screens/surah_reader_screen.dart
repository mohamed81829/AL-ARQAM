import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../services/quran_audio.dart';
import 'recitation_screen.dart';

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
  final QuranAudio _audio = QuranAudio.instance;
  double _fontSize = 28;
  int? _marked;

  @override
  void initState() {
    super.initState();
    _chapter = QuranRepository.chapters
        .firstWhere((c) => c.id == widget.chapterId);
    _verses = QuranRepository.verses(widget.chapterId);
    _keys = List.generate(_verses.length, (_) => GlobalKey());
    _audio.init().then((_) {
      if (mounted) setState(() {});
    });
    _audio.currentVerse.addListener(_onAudioVerse);
    _audio.error.addListener(_onAudioError);
    _loadPrefs();
  }

  @override
  void dispose() {
    _audio.currentVerse.removeListener(_onAudioVerse);
    _audio.error.removeListener(_onAudioError);
    _audio.stop();
    super.dispose();
  }

  void _onAudioVerse() {
    if (!mounted) return;
    setState(() {});
    final v = _audio.currentVerse.value;
    if (v != null && _audio.currentChapter.value == widget.chapterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTo(v, animate: true);
      });
    }
  }

  void _onAudioError() {
    final msg = _audio.error.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
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

  void _scrollTo(int verse, {bool animate = false}) {
    if (verse < 1 || verse > _keys.length) return;
    final ctx = _keys[verse - 1].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: animate ? 0.3 : 0.1,
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
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

  void _togglePlay() {
    final active = _audio.currentChapter.value == widget.chapterId &&
        _audio.currentVerse.value != null;
    if (active) {
      if (_audio.playing.value) {
        _audio.pause();
      } else {
        _audio.resume();
      }
    } else {
      _audio.playFrom(widget.chapterId, _marked ?? 1, _verses.length);
    }
  }

  Future<void> _toggleMode() async {
    await _audio.setContinuous(!_audio.continuous);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _audio.continuous
                ? 'قراءة متواصلة: الآيات تتتابع لآخر السورة'
                : 'آية آية: التلاوة بتقف بعد كل آية',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openRecitation() async {
    await _audio.stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecitationScreen(
          chapterId: widget.chapterId,
          startVerse: _marked ?? 1,
        ),
      ),
    );
  }

  void _pickReciter() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'اختر القارئ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              for (final r in reciters)
                ListTile(
                  title: Text(r.name),
                  trailing:
                      r.id == _audio.reciter.id ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _audio.setReciter(r);
                    setState(() {});
                  },
                ),
            ],
          ),
        );
      },
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
    final isPlaying = _audio.currentChapter.value == widget.chapterId &&
        _audio.currentVerse.value == v.number;

    return InkWell(
      key: _keys[i],
      borderRadius: BorderRadius.circular(8),
      onTap: () => _mark(v.number),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isPlaying
              ? scheme.tertiaryContainer
              : (marked ? scheme.primaryContainer : null),
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

  Widget _playerBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        color: scheme.secondaryContainer,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _audio.playing,
            _audio.loading,
            _audio.currentVerse,
            _audio.currentChapter,
          ]),
          builder: (context, _) {
            final active = _audio.currentChapter.value == widget.chapterId &&
                _audio.currentVerse.value != null;
            final isPlaying = active && _audio.playing.value;
            final isLoading = active && _audio.loading.value;
            final verse = _audio.currentVerse.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'الآية السابقة',
                          icon: const Icon(Icons.skip_previous),
                          onPressed: active ? _audio.previous : null,
                        ),
                        if (isLoading)
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                            iconSize: 36,
                            icon: Icon(
                              isPlaying ? Icons.pause_circle : Icons.play_circle,
                            ),
                            onPressed: _togglePlay,
                          ),
                        IconButton(
                          tooltip: 'الآية التالية',
                          icon: const Icon(Icons.skip_next),
                          onPressed: active ? _audio.next : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _pickReciter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _audio.reciter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              active && verse != null
                                  ? 'الآية $verse من ${_verses.length} • ${_audio.continuous ? 'متواصل' : 'آية آية'}'
                                  : 'اضغط هنا لتغيير القارئ',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _audio.continuous
                        ? 'قراءة متواصلة (اضغط للتحويل لآية آية)'
                        : 'آية آية (اضغط للتحويل لمتواصلة)',
                    icon: Icon(
                      _audio.continuous
                          ? Icons.playlist_play
                          : Icons.looks_one_outlined,
                    ),
                    onPressed: _toggleMode,
                  ),
                ],
              ),
            );
          },
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
            tooltip: 'تسميع',
            icon: const Icon(Icons.mic),
            onPressed: _openRecitation,
          ),
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
      bottomNavigationBar: _playerBar(),
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
