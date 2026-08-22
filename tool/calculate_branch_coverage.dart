import 'dart:convert';
import 'dart:io';

void main() {
  final coverageDir = Directory('coverage');
  if (!coverageDir.existsSync()) {
    print('Coverage directory not found.');
    exit(1);
  }

  // Map of file URI -> Map of branch ID -> hit count
  final fileBranchHits = <String, Map<int, int>>{};
  final fileLineHits = <String, Map<int, int>>{};

  for (final file in coverageDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;

    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final coverageList = json['coverage'] as List<dynamic>? ?? [];

      for (final item in coverageList) {
        final source = item['source'] as String?;
        if (source == null || !source.startsWith('package:dart_book/')) continue;

        // Line hits
        final lineHitsMap = fileLineHits.putIfAbsent(source, () => <int, int>{});
        final lineHits = item['hits'] as List<dynamic>? ?? [];
        for (var i = 0; i < lineHits.length; i += 2) {
          final line = lineHits[i] as int;
          final count = lineHits[i + 1] as int;
          lineHitsMap[line] = (lineHitsMap[line] ?? 0) + count;
        }

        // Branch hits (if available in modern Dart VM coverage)
        final branchHitsList = item['branchHits'] as List<dynamic>? ?? [];
        if (branchHitsList.isNotEmpty) {
          final branchHitsMap = fileBranchHits.putIfAbsent(source, () => <int, int>{});
          for (var i = 0; i < branchHitsList.length; i += 2) {
            final branchId = branchHitsList[i] as int;
            final count = branchHitsList[i + 1] as int;
            branchHitsMap[branchId] = (branchHitsMap[branchId] ?? 0) + count;
          }
        }
      }
    } catch (_) {}
  }

  print('════════════════════════════════════════════════════════════════════════════════');
  print('                    АНАЛИЗ ПОКРЫТИЯ ВЕТВЛЕНИЙ (BRANCH COVERAGE)                 ');
  print('════════════════════════════════════════════════════════════════════════════════\n');

  final hasBranchData = fileBranchHits.isNotEmpty;
  if (!hasBranchData) {
    print('Файлы профилирования не содержат сырых branchHits (использовался стандартный формат).');
    return;
  }

  var totalBranches = 0;
  var hitBranches = 0;

  var handTotalBranches = 0;
  var handHitBranches = 0;

  final sortedSources = fileBranchHits.keys.toList()..sort();

  print('Файл / Модуль                                         Ветви      Покрыто      %');
  print('────────────────────────────────────────────────────────────────────────────────');

  for (final source in sortedSources) {
    final hits = fileBranchHits[source]!;
    final total = hits.length;
    final hit = hits.values.where((c) => c > 0).length;
    final percent = total > 0 ? (hit / total * 100).toStringAsFixed(1) : '100.0';

    totalBranches += total;
    hitBranches += hit;

    if (!source.contains('/.gen/')) {
      handTotalBranches += total;
      handHitBranches += hit;
    }

    final shortName = source.replaceFirst('package:dart_book/', '');
    final paddedName = shortName.length > 48 ? '${shortName.substring(0, 45)}...' : shortName.padRight(48);
    print('$paddedName ${total.toString().padLeft(6)}     ${hit.toString().padLeft(6)}   ${percent.padLeft(5)}%');


  }

  print('────────────────────────────────────────────────────────────────────────────────');
  final totalPercent = totalBranches > 0 ? (hitBranches / totalBranches * 100).toStringAsFixed(2) : '0.00';
  final handPercent = handTotalBranches > 0 ? (handHitBranches / handTotalBranches * 100).toStringAsFixed(2) : '0.00';
  print('ИТОГО BRANCH COVERAGE (ВСЕ ФАЙЛЫ):                  ${totalBranches.toString().padLeft(6)}     ${hitBranches.toString().padLeft(6)}   ${totalPercent.padLeft(5)}%');
  print('ИТОГО BRANCH COVERAGE (РУКОПИСНЫЙ КОД):              ${handTotalBranches.toString().padLeft(6)}     ${handHitBranches.toString().padLeft(6)}   ${handPercent.padLeft(5)}%');
  print('\n════════════════════════════════════════════════════════════════════════════════');
}
