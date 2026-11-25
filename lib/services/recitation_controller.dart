import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'recitation_checker.dart';

enum RecitationState { idle, listening, wrong, missed, stuck, complete, error }

class RecitationController extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechReady = false;
  bool _ttsReady = false;
  String? _localeId;

  RecitationState state = RecitationState.idle;
  List<String> words = [];
  int confirmed = 0;
  int? mistakeIndex;
  String? heard;
  String? errorText;

  RecitationChecker? _checker;
  int _baseIndex = 0;
  int _restarts = 0;
  int _sessionId = 0;
  bool _restartScheduled = false;
  DateTime _listenStartedAt = DateTime.now();
  Timer? _stuckTimer;
  Timer? _pendingTimer;
  bool _disposed = false;

  bool get isListening => state == RecitationState.listening;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _ensureSpeech() async {
    if (_speechReady) return true;
    try {
      _speechReady = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (_speechReady) {
        final locales = await _speech.locales();
        LocaleName? pick;
        for (final l in locales) {
          final id = l.localeId.toLowerCase();
          if (id.startsWith('ar')) {
            if (pick == null || id.contains('sa') || id.contains('eg')) {
              pick = l;
            }
          }
        }
        _localeId = pick?.localeId;
      }
    } catch (_) {
      _speechReady = false;
    }
    return _speechReady;
  }

  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.45);
      _ttsReady = true;
    } catch (_) {}
  }

  Future<void> _announce(String phrase) async {
    HapticFeedback.heavyImpact();
    try {
      await _ensureTts();
      await _tts.speak(phrase);
    } catch (_) {}
  }

  /// يبدأ الاستماع لتسميع آية.
  Future<void> start(String verseText) async {
    await _halt();
    words = verseText
        .split(' ')
        .where((w) => WordCheck.normalize(w).isNotEmpty)
        .toList();
    _checker = RecitationChecker(words);
    confirmed = 0;
    mistakeIndex = null;
    heard = null;
    errorText = null;
    _baseIndex = 0;
    _restarts = 0;
    _restartScheduled = false;

    final ok = await _ensureSpeech();
    if (!ok) {
      _fail('التعرف على الكلام غير متاح. تأكد من السماح بالميكروفون '
          'وتثبيت خدمة جوجل للكلام.');
      return;
    }
    if (_localeId == null) {
      _fail('اللغة العربية غير متاحة في التعرف على الكلام. '
          'فعّلها من إعدادات خدمة جوجل للكلام.');
      return;
    }
    state = RecitationState.listening;
    _safeNotify();
    await _listen();
  }

  Future<void> _listen() async {
    _baseIndex = confirmed;
    final id = ++_sessionId;
    _listenStartedAt = DateTime.now();
    _armStuckTimer();
    try {
      await _speech.listen(
        onResult: (r) => _onResult(r, id),
        localeId: _localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 6),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      if (id == _sessionId) _fail('تعذر بدء الاستماع.');
    }
  }

  void _onResult(SpeechRecognitionResult r, int id) {
    if (id != _sessionId || state != RecitationState.listening) return;
    _pendingTimer?.cancel();
    final spoken = r.recognizedWords
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final res =
        _checker!.evaluate(_baseIndex, spoken, isFinal: r.finalResult);

    if (res.confirmed > confirmed) {
      confirmed = res.confirmed;
      _armStuckTimer();
    }
    if (res.mistakeIndex != null && !res.pending) {
      _flag(res);
      return;
    }
    if (res.complete) {
      _finishOk();
      return;
    }
    if (res.mistakeIndex != null && res.pending) {
      // آخر كلمة لسه بتتكوّن: نستنى شوية ونتأكد قبل ما نقول "أخطأت"
      _pendingTimer = Timer(const Duration(milliseconds: 1500), () {
        if (state == RecitationState.listening && id == _sessionId) {
          _flag(res);
        }
      });
    }
    _safeNotify();
  }

  Future<void> _flag(RecitationResult res) async {
    mistakeIndex = res.mistakeIndex;
    heard = res.heard;
    state = res.missed ? RecitationState.missed : RecitationState.wrong;
    await _stopListening();
    _safeNotify();
    _announce(res.missed ? 'حسبك' : 'أخطأت');
  }

  void _armStuckTimer() {
    _stuckTimer?.cancel();
    final secs = confirmed == 0 ? 9 : 6;
    _stuckTimer = Timer(Duration(seconds: secs), _onStuck);
  }

  void _onStuck() {
    if (state != RecitationState.listening) return;
    mistakeIndex = confirmed < words.length ? confirmed : null;
    heard = null;
    state = RecitationState.stuck;
    _stopListening();
    _safeNotify();
    _announce('حسبك');
  }

  Future<void> _finishOk() async {
    confirmed = words.length;
    mistakeIndex = null;
    state = RecitationState.complete;
    await _stopListening();
    _safeNotify();
    HapticFeedback.lightImpact();
    try {
      await _ensureTts();
      await _tts.speak('أحسنت');
    } catch (_) {}
  }

  void _fail(String message) {
    state = RecitationState.error;
    errorText = message;
    _stopListening();
    _safeNotify();
  }

  // أندرويد بيقفل جلسة الاستماع لوحده بعد وقفة، فبنعيدها من آخر كلمة صح
  void _onStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    if (state != RecitationState.listening) return;
    if (DateTime.now().difference(_listenStartedAt) <
        const Duration(milliseconds: 600)) {
      return;
    }
    _sessionEnded();
  }

  void _onError(SpeechRecognitionError e) {
    if (state != RecitationState.listening) return;
    if (e.permanent) {
      _fail('تعذر الاستماع (${e.errorMsg}).');
      return;
    }
    _sessionEnded();
  }

  void _sessionEnded() {
    if (_restartScheduled) return;
    if (_restarts >= 8) {
      _onStuck();
      return;
    }
    _restarts++;
    _restartScheduled = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _restartScheduled = false;
      if (state == RecitationState.listening) _listen();
    });
  }

  Future<void> _stopListening() async {
    _stuckTimer?.cancel();
    _pendingTimer?.cancel();
    _sessionId++;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> _halt() async {
    _stuckTimer?.cancel();
    _pendingTimer?.cancel();
    _sessionId++;
    try {
      if (_speechReady) await _speech.cancel();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// يوقف الاستماع ويرجّع الحالة لوضع الراحة.
  Future<void> stop() async {
    await _halt();
    state = RecitationState.idle;
    confirmed = 0;
    mistakeIndex = null;
    heard = null;
    errorText = null;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stuckTimer?.cancel();
    _pendingTimer?.cancel();
    try {
      _speech.cancel();
    } catch (_) {}
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }
}
