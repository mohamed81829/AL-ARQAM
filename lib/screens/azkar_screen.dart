import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/azkar_data.dart';

class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> {
  String _set = azkarSets.keys.first;
  final Map<String, List<int>> _remaining = {
    for (final e in azkarSets.entries) e.key: [for (final z in e.value) z.count],
  };

  void _tap(int i) {
    final list = _remaining[_set]!;
    if (list[i] > 0) {
      setState(() => list[i]--);
      HapticFeedback.selectionClick();
    }
  }

  void _reset() => setState(() {
        _remaining[_set] = [for (final z in azkarSets[_set]!) z.count];
      });

  @override
  Widget build(BuildContext context) {
    final items = azkarSets[_set]!;
    final left = _remaining[_set]!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final k in azkarSets.keys)
                      ChoiceChip(
                        label: Text(k),
                        selected: _set == k,
                        onSelected: (_) => setState(() => _set = k),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'إعادة',
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final done = left[i] == 0;
              return Card(
                color: done ? scheme.primaryContainer : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _tap(i),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].text,
                            style: const TextStyle(fontSize: 20, height: 1.8)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('التكرار: ${items[i].count}'),
                            done
                                ? const Icon(Icons.check_circle)
                                : Text('المتبقي: ${left[i]}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
