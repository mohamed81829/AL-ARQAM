import 'package:flutter/material.dart';

import '../data/hifz_store.dart';
import '../data/quran_repository.dart';
import 'hifz_session_screen.dart';

class HifzScreen extends StatefulWidget {
  const HifzScreen({super.key});

  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> {
  final HifzStore _store = HifzStore.instance;
  bool _loading = true;
  bool _editing = false;

  int _setupChapter = 1;
  int _setupDaily = 5;
  final TextEditingController _startCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await QuranRepository.load();
    } catch (_) {}
    await _store.load();
    final p = _store.plan;
    if (p != null) {
      _setupChapter = p.chapter;
      _startCtrl.text = '${p.nextVerse}';
      _setupDaily = p.dailyNew;
    }
    _editing = p == null;
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Chapter _chapterOf(int id) =>
      QuranRepository.chapters.firstWhere((c) => c.id == id);

  Future<void> _savePlan() async {
    final chapter = _chapterOf(_setupChapter);
    final start = int.tryParse(_startCtrl.text.trim()) ?? 1;
    final clamped = start < 1
        ? 1
        : (start > chapter.totalVerses ? chapter.totalVerses : start);
    await _store.setPlan(_setupChapter, clamped, _setupDaily);
    if (!mounted) return;
    setState(() => _editing = false);
  }

  Future<void> _startNew(Chapter chapter, List<int> verses) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HifzSessionScreen(
          mode: HifzMode.newVerses,
          items: [for (final v in verses) VerseRef(chapter.id, v)],
        ),
      ),
    );
    await _afterSession();
  }

  Future<void> _startReview(List<ReviewItem> due) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HifzSessionScreen(
          mode: HifzMode.review,
          items: [for (final r in due) VerseRef(r.chapter, r.verse)],
        ),
      ),
    );
    await _afterSession();
  }

  Future<void> _afterSession() async {
    final plan = _store.plan;
    if (plan != null) {
      final ch = _chapterOf(plan.chapter);
      final allDone = _store.todayNewVerses(ch.totalVerses).isEmpty &&
          _store.dueReviews().isEmpty;
      await _store.updateStreak(allDone);
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحفظ والورد اليومي'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_editing ? _setupView() : _todayView()),
    );
  }

  Widget _setupView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('اختر السورة التي تحفظها',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButton<int>(
          isExpanded: true,
          value: _setupChapter,
          items: [
            for (final c in QuranRepository.chapters)
              DropdownMenuItem(value: c.id, child: Text('${c.id}. ${c.name}')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _setupChapter = v);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _startCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'ابدأ من الآية رقم',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const Text('عدد الآيات الجديدة كل يوم',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (final n in [3, 5, 10])
              ButtonSegment<int>(value: n, label: Text('$n')),
          ],
          selected: {_setupDaily},
          onSelectionChanged: (s) => setState(() => _setupDaily = s.first),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _savePlan, child: const Text('حفظ الخطة')),
        if (_store.plan != null)
          TextButton(
            onPressed: () => setState(() => _editing = false),
            child: const Text('إلغاء'),
          ),
      ],
    );
  }

  Widget _todayView() {
    final plan = _store.plan!;
    final chapter = _chapterOf(plan.chapter);
    final newVerses = _store.todayNewVerses(chapter.totalVerses);
    final due = _store.dueReviews();
    final finished = plan.nextVerse > chapter.totalVerses;
    final newDoneToday = _store.lastNewDate == _store.today;

    String newSubtitle;
    if (finished) {
      newSubtitle = 'أتممت حفظ السورة. اختر سورة جديدة من "تغيير الخطة".';
    } else if (newDoneToday || newVerses.isEmpty) {
      newSubtitle = 'تم حفظ ورد اليوم ✓';
    } else if (newVerses.first == newVerses.last) {
      newSubtitle = 'الآية ${newVerses.first}';
    } else {
      newSubtitle = 'الآيات ${newVerses.first} إلى ${newVerses.last}';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_fire_department),
            title: Text('أيام متتالية: ${_store.currentStreak}'),
            subtitle: Text('عدد الآيات المحفوظة: ${_store.memorizedCount}'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.flag),
            title: Text('خطتك: سورة ${chapter.name}'),
            subtitle: Text(
              finished
                  ? 'أتممت حفظ السورة 🎉'
                  : 'الآية التالية ${plan.nextVerse} من ${chapter.totalVerses}'
                      ' • ${plan.dailyNew} آيات يومياً',
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('تغيير الخطة'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('حفظ جديد'),
            subtitle: Text(newSubtitle),
            trailing: newVerses.isNotEmpty
                ? FilledButton(
                    onPressed: () => _startNew(chapter, newVerses),
                    child: const Text('ابدأ'),
                  )
                : null,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.replay),
            title: const Text('المراجعة'),
            subtitle: Text(
              due.isEmpty
                  ? 'لا مراجعات مستحقة اليوم ✓'
                  : '${due.length} آية للمراجعة',
            ),
            trailing: due.isNotEmpty
                ? FilledButton(
                    onPressed: () => _startReview(due),
                    child: const Text('ابدأ'),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
