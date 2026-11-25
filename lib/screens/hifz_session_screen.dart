import 'package:flutter/material.dart';

import '../data/hifz_store.dart';
import '../data/quran_repository.dart';
import '../services/quran_audio.dart';
import '../services/recitation_controller.dart';

enum HifzMode { newVerses, review }

class HifzSessionScreen extends StatefulWidget {
  final HifzMode mode;
  final List<VerseRef> items;

  const HifzSessionScreen({
    super.key,
    required this.mode,
    required this.items,
  });

  @override
  State<HifzSessionScreen> createState() => _HifzSessionScreenState();
}

class _HifzSessionScreenState extends State<HifzSessionScreen> {
  final HifzStore _store = HifzStore.instance;
  final QuranAudio _audio = QuranAudio.instance;
  final RecitationController _rec = RecitationController();

  int _index = 0;
  bool _hidden = false;
  bool _hint = false;
  bool _finished = false;
  int _remembered = 0;
  int _forgotten = 0;
  String? _message;

  bool get _isNew => widget.mode == HifzMode.newVerses;
  VerseRef get _current => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _hidden = !_isNew;
    _audio.init();
    _audio.error.addListener(_onAudioError);
    _rec.addListener(_onRec);
  }

  @override
  void dispose() {
    _audio.error.removeListener(_onAudioError);
    _rec.removeListener(_onRec);
    _rec.dispose();
    _audio.stop();
    super.dispose();
  }

  void _onRec() {
    if (mounted) setState(() {});
  }

  void _onAudioError() {
    final msg = _audio.error.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _textOf(VerseRef r) {
    final verses = QuranRepository.verses(r.chapter);
    final text = verses[r.verse - 1].text;
    return r.verse == 1 ? QuranRepository.stripBismillah(r.chapter, text) : text;
  }

  void _listen() {
    if (_rec.isListening) return;
    final r = _current;
    _audio.playFrom(r.chapter, r.verse, r.verse);
  }

  Future<void> _toggleRecite() async {
    if (_rec.isListening) {
      await _rec.stop();
      return;
    }
    await _audio.stop();
    setState(() {
      _hidden = true;
      _hint = false;
      _message = null;
    });
    await _rec.start(_textOf(_current));
  }

  void _goNext() {
    _rec.stop();
    if (_index + 1 >= widget.items.length) {
      _finish();
    } else {
      _audio.stop();
      setState(() {
        _index++;
        _hidden = !_isNew;
        _hint = false;
        _message = null;
      });
    }
  }

  Future<void> _finish() async {
    if (_isNew) await _store.finishNewSession();
    await _audio.stop();
    if (!mounted) return;
    setState(() => _finished = true);
  }

  Future<void> _memorized() async {
    final r = _current;
    await _store.markMemorized(r.chapter, r.verse);
    _remembered++;
    _goNext();
  }

  void _notYet() {
    setState(() {
      _hidden = true;
      _message = 'كرّر الاستماع، وحاول تسمّعها من غير ما تبص. '
          'ولما تحفظها اضغط "حفظتها".';
    });
  }

  Future<void> _rateReview(bool remembered) async {
    final r = _current;
    final item = _store.reviewOf(r.chapter, r.verse);
    if (item != null) await _store.rateReview(item, remembered);
    if (remembered) {
      _remembered++;
    } else {
      _forgotten++;
    }
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'حفظ جديد' : 'مراجعة'),
        centerTitle: true,
      ),
      body: SafeArea(child: _finished ? _doneView() : _cardView()),
    );
  }

  Widget _doneView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              _isNew
                  ? 'أحسنت! خلّصت حفظ ورد اليوم'
                  : 'خلّصت المراجعة: عرفت $_remembered ونسيت $_forgotten',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recitationView() {
    final shown = _rec.confirmed.clamp(0, _rec.words.length);
    final children = <Widget>[];
    for (var i = 0; i < shown; i++) {
      children.add(
        Text(
          _rec.words[i],
          style: TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: 28,
            height: 2.0,
            color: Colors.green.shade700,
          ),
        ),
      );
    }
    final m = _rec.mistakeIndex;
    if (m != null && m < _rec.words.length) {
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _rec.words[m],
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 28,
              height: 2.0,
              color: Colors.red.shade900,
            ),
          ),
        ),
      );
    }
    if (children.isEmpty) {
      children.add(const Icon(Icons.mic, size: 48));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: children,
    );
  }

  Widget _recStatus() {
    final state = _rec.state;
    if (state == RecitationState.idle) return const SizedBox.shrink();
    final heard = _rec.heard;
    final String msg = switch (state) {
      RecitationState.idle => '',
      RecitationState.listening => 'جاري الاستماع... سمّع الآية من ذاكرتك',
      RecitationState.wrong => (heard == null || heard.isEmpty)
          ? 'أخطأت ✗ — الكلمة الصحيحة بالأحمر'
          : 'أخطأت ✗ — سمعتك تقول "$heard" والصح بالأحمر',
      RecitationState.missed => 'حسبك ✋ نسيت كلمة — الكلمة الصحيحة بالأحمر',
      RecitationState.stuck => 'حسبك ✋ توقفت — الكلمة الجاية بالأحمر',
      RecitationState.complete => 'أحسنت ✓ سمّعتها كاملة',
      RecitationState.error => _rec.errorText ?? 'حصل خطأ',
    };
    Color? color;
    if (state == RecitationState.wrong ||
        state == RecitationState.missed ||
        state == RecitationState.stuck ||
        state == RecitationState.error) {
      color = Colors.red.shade700;
    } else if (state == RecitationState.complete) {
      color = Colors.green.shade700;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _contentArea(String text, String firstWords) {
    if (_hidden) {
      if (_rec.state != RecitationState.idle) return _recitationView();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_off, size: 48),
          if (_hint) ...[
            const SizedBox(height: 16),
            Text(
              '$firstWords …',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 28,
                height: 2.0,
              ),
            ),
          ],
        ],
      );
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'AmiriQuran',
        fontSize: 30,
        height: 2.0,
      ),
    );
  }

  Widget _cardView() {
    final r = _current;
    final chapter =
        QuranRepository.chapters.firstWhere((c) => c.id == r.chapter);
    final text = _textOf(r);
    final firstWords = text.split(' ').take(3).join(' ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(value: _index / widget.items.length),
          const SizedBox(height: 8),
          Text('${_index + 1} من ${widget.items.length}'),
          const SizedBox(height: 16),
          Text(
            'سورة ${chapter.name} - الآية ${r.verse}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: _contentArea(text, firstWords),
              ),
            ),
          ),
          _recStatus(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _toggleRecite,
                icon: Icon(_rec.isListening ? Icons.stop : Icons.mic),
                label: Text(
                  _rec.isListening
                      ? 'إيقاف'
                      : (_rec.state == RecitationState.idle
                          ? 'سمّع'
                          : 'أعد المحاولة'),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _listen,
                icon: const Icon(Icons.volume_up),
                label: const Text('استمع'),
              ),
              if (_hidden && !_hint && _rec.state == RecitationState.idle)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _hint = true),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('تلميح'),
                ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                label: Text(_hidden ? 'إظهار' : 'إخفاء'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isNew ? _notYet : () => _rateReview(false),
                  child: Text(_isNew ? 'لسه' : 'نسيتها'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isNew ? _memorized : () => _rateReview(true),
                  child: Text(_isNew ? 'حفظتها ✓' : 'عرفتها ✓'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
