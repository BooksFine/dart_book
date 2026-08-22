import 'dart:convert';
import 'dart:io';

void main() {
  final coverageDir = Directory('coverage');
  if (!coverageDir.existsSync()) {
    print('Coverage directory not found.');
    exit(1);
  }

  final fileHits = <String, Map<int, int>>{};

  for (final file in coverageDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;

    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final coverageList = json['coverage'] as List<dynamic>? ?? [];

      for (final item in coverageList) {
        final source = item['source'] as String?;
        if (source == null || !source.startsWith('package:dart_book/')) continue;

        final hitsMap = fileHits.putIfAbsent(source, () => <int, int>{});
        final hits = item['hits'] as List<dynamic>? ?? [];

        for (var i = 0; i < hits.length; i += 2) {
          final line = hits[i] as int;
          final count = hits[i + 1] as int;
          hitsMap[line] = (hitsMap[line] ?? 0) + count;
        }
      }
    } catch (_) {}
  }

  var totalLines = 0;
  var hitLines = 0;
  var handTotalLines = 0;
  var handHitLines = 0;

  final sortedSources = fileHits.keys.toList()..sort();

  for (final source in sortedSources) {
    final hits = fileHits[source]!;
    final total = hits.length;
    final hit = hits.values.where((c) => c > 0).length;

    totalLines += total;
    hitLines += hit;

    if (!source.contains('/.gen/')) {
      handTotalLines += total;
      handHitLines += hit;
    }
  }

  print('Общее покрытие (включая .gen/): ${(hitLines / totalLines * 100).toStringAsFixed(2)}%');
  print('Покрытие рукописного кода (без кодогенерации Freezed): ${(handHitLines / handTotalLines * 100).toStringAsFixed(2)}% ($handHitLines из $handTotalLines строк)');
}
