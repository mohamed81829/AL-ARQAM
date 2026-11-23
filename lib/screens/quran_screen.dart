import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import 'surah_reader_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  bool _loading = true;
  bool _failed = false;
  String _query = '';
  (int, int)? _last;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await QuranRepository.load();
      _last = await QuranRepository.lastRead();
    } catch (_) {
      _failed = true;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _open(int chapter, {int verse = 1}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SurahReaderScreen(chapterId: chapter, initialVerse: verse),
      ),
    );
    final last = await QuranRepository.lastRead();
    if (!mounted) return;
    setState(() => _last = last);
  }

  List<Chapter> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return QuranRepository.chapters;
    return QuranRepository.chapters
        .where((c) =>
            c.name.contains(q) ||
            c.transliteration.toLowerCase().contains(q) ||
            c.id.toString() == q)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('تعذر تحميل المصحف', textAlign: TextAlign.center),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final chapters = _filtered;
    final last = _last;
    final lastChapter = last == null
        ? null
        : QuranRepository.chapters.where((c) => c.id == last.$1).firstOrNull;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث عن سورة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (last != null && lastChapter != null && _query.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Card(
              color: scheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('متابعة القراءة'),
                subtitle: Text('سورة ${lastChapter.name} - آية ${last.$2}'),
                onTap: () => _open(last.$1, verse: last.$2),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: chapters.length + 1,
            itemBuilder: (context, i) {
              if (i == chapters.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'نص المصحف (الرسم العثماني) من مشروع تنزيل - tanzil.net',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                );
              }
              final c = chapters[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${c.id}')),
                title: Text(
                  c.name,
                  style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 22),
                ),
                subtitle: Text(
                  '${c.isMeccan ? 'مكية' : 'مدنية'} • ${c.totalVerses} آية',
                ),
                trailing: Text(
                  c.transliteration,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => _open(c.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
