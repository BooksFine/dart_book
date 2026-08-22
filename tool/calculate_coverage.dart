import 'dart:convert';
import 'dart:io';

void main() {
  final coverageDir = Directory('coverage');
  if (!coverageDir.existsSync()) {
    print('Coverage directory not found. Run "dart test --coverage=coverage" first.');
    exit(1);
  }

  // Map of file URI -> Map of line number -> hit count
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

  final sortedSources = fileHits.keys.toList()..sort();

  print('════════════════════════════════════════════════════════════════════════════════');
  print('                    ОТЧЕТ О ПОКРЫТИИ ТЕСТАМИ (CODE COVERAGE)                    ');
  print('════════════════════════════════════════════════════════════════════════════════\n');

  print('Файл / Модуль                                          Строки     Покрыто     %');
  print('────────────────────────────────────────────────────────────────────────────────');

  final groups = <String, (int total, int hit)>{};

  for (final source in sortedSources) {
    final hits = fileHits[source]!;
    final total = hits.length;
    final hit = hits.values.where((c) => c > 0).length;
    final percent = total > 0 ? (hit / total * 100).toStringAsFixed(1) : '100.0';

    totalLines += total;
    hitLines += hit;

    final shortName = source.replaceFirst('package:dart_book/', '');
    final paddedName = shortName.length > 50 ? '${shortName.substring(0, 47)}...' : shortName.padRight(50);

    print('$paddedName ${total.toString().padLeft(6)}     ${hit.toString().padLeft(6)}   ${percent.padLeft(5)}%');

    // Grouping
    final groupKey = shortName.contains('/') ? '${shortName.split('/')[0]}/${shortName.split('/')[1]}' : shortName;

    final current = groups[groupKey] ?? (0, 0);
    groups[groupKey] = (current.$1 + total, current.$2 + hit);
  }

  print('────────────────────────────────────────────────────────────────────────────────');
  final totalPercent = totalLines > 0 ? (hitLines / totalLines * 100).toStringAsFixed(2) : '0.00';
  print('ИТОГО ПО ВСЕЙ БИБЛИОТЕКЕ:                            ${totalLines.toString().padLeft(6)}     ${hitLines.toString().padLeft(6)}   ${totalPercent.padLeft(5)}%\n');

  print('📊 Сводка по основным модулям:');
  for (final entry in groups.entries) {
    final t = entry.value.$1;
    final h = entry.value.$2;
    final p = t > 0 ? (h / t * 100).toStringAsFixed(1) : '100.0';
    print('   • ${entry.key.padRight(35)}: ${p.padLeft(5)}% ($h из $t строк)');
  }
  print('\n════════════════════════════════════════════════════════════════════════════════');
}
