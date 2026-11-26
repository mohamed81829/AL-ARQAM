import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Reciter {
  final String id;
  final String name;
  const Reciter(this.id, this.name);
}

/// القرّاء المتاحون (التلاوة من موقع EveryAyah آية آية).
const reciters = <Reciter>[
  Reciter('Minshawy_Murattal_128kbps', 'المنشاوي - مرتل'),
  Reciter('Minshawy_Mujawwad_192kbps', 'المنشاوي - مجوّد'),
  Reciter('Husary_128kbps', 'الحصري - مرتل'),
  Reciter('Abdul_Basit_Murattal_192kbps', 'عبد الباسط - مرتل'),
  Reciter('Abdul_Basit_Mujawwad_128kbps', 'عبد الباسط - مجوّد'),
  Reciter('mahmoud_ali_al_banna_32kbps', 'محمود علي البنا'),
  Reciter('Mustafa_Ismail_48kbps', 'مصطفى إسماعيل'),
  Reciter('Ghamadi_40kbps', 'سعد الغامدي'),
  Reciter('Alafasy_128kbps', 'مشاري العفاسي'),
  Reciter('Abdurrahmaan_As-Sudais_192kbps', 'عبد الرحمن السديس'),
  Reciter('Saood_ash-Shuraym_128kbps', 'سعود الشريم'),
  Reciter('MaherAlMuaiqly128kbps', 'ماهر المعيقلي'),
];

class QuranAudio {
  QuranAudio._();
  static final QuranAudio instance = QuranAudio._();

  final AudioPlayer _player = AudioPlayer();

  final ValueNotifier<int?> currentChapter = ValueNotifier<int?>(null);
  final ValueNotifier<int?> currentVerse = ValueNotifier<int?>(null);
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  Reciter reciter = reciters.first;
  bool continuous = true; // true: متواصل، false: آية آية
  int _totalVerses = 0;
  int _token = 0; // لتجاهل أحداث الآيات القديمة بعد التبديل
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final p = await SharedPreferences.getInstance();
      final id = p.getString('quran_reciter');
      for (final r in reciters) {
        if (r.id == id) reciter = r;
      }
      continuous = p.getBool('quran_continuous') ?? true;
    } catch (_) {}
  }

  Future<void> setContinuous(bool value) async {
    continuous = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('quran_continuous', value);
    } catch (_) {}
  }

  String _url(int chapter, int verse) {
    final s = chapter.toString().padLeft(3, '0');
    final a = verse.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/${reciter.id}/$s$a.mp3';
  }

  /// يبدأ التلاوة من آية معيّنة ويكمل لحد آخر السورة.
  Future<void> playFrom(int chapter, int verse, int totalVerses) async {
    _totalVerses = totalVerses;
    await _playVerse(chapter, verse);
  }

  Future<void> _playVerse(int chapter, int verse) async {
    final token = ++_token;
    currentChapter.value = chapter;
    currentVerse.value = verse;
    loading.value = true;
    playing.value = false;
    error.value = null;
    try {
      await _player.setUrl(_url(chapter, verse));
      if (token != _token) return;
      loading.value = false;
      playing.value = true;
      await _listenToEnd(token, chapter, verse);
    } on PlayerInterruptedException {
      return;
    } catch (_) {
      if (token != _token) return;
      loading.value = false;
      playing.value = false;
      error.value = 'تعذر تشغيل التلاوة. تأكد من الاتصال بالإنترنت.';
    }
  }

  Future<void> _listenToEnd(int token, int chapter, int verse) async {
    await _player.play();
    if (token != _token) return;
    if (_player.processingState == ProcessingState.completed) {
      if (continuous && verse < _totalVerses) {
        _playVerse(chapter, verse + 1);
      } else {
        playing.value = false;
      }
    }
  }

  Future<void> pause() async {
    playing.value = false;
    await _player.pause();
  }

  Future<void> resume() async {
    final c = currentChapter.value;
    final v = currentVerse.value;
    if (c == null || v == null) return;
    if (error.value != null) {
      _playVerse(c, v);
      return;
    }
    playing.value = true;
    try {
      // لو الآية خلصت (وضع آية آية) نعيدها من أولها
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
    } catch (_) {}
    _listenToEnd(_token, c, v);
  }

  Future<void> next() async {
    final c = currentChapter.value;
    final v = currentVerse.value;
    if (c == null || v == null) return;
    if (v < _totalVerses) await _playVerse(c, v + 1);
  }

  Future<void> previous() async {
    final c = currentChapter.value;
    final v = currentVerse.value;
    if (c == null || v == null) return;
    if (v > 1) await _playVerse(c, v - 1);
  }

  Future<void> stop() async {
    _token++;
    playing.value = false;
    loading.value = false;
    currentVerse.value = null;
    currentChapter.value = null;
    error.value = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> setReciter(Reciter r) async {
    reciter = r;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('quran_reciter', r.id);
    } catch (_) {}
    final c = currentChapter.value;
    final v = currentVerse.value;
    if (c != null && v != null) await _playVerse(c, v);
  }
}
