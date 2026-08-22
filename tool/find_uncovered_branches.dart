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
        if (source == null || !source.startsWith('package:dart_book/')) {
          continue;
        }

        // Line hits
        final lineHitsMap = fileLineHits.putIfAbsent(
          source,
          () => <int, int>{},
        );
        final lineHits = item['hits'] as List<dynamic>? ?? [];
        for (var i = 0; i < lineHits.length; i += 2) {
          final line = lineHits[i] as int;
          final count = lineHits[i + 1] as int;
          lineHitsMap[line] = (lineHitsMap[line] ?? 0) + count;
        }

        // Branch hits
        final branchHitsList = item['branchHits'] as List<dynamic>? ?? [];
        if (branchHitsList.isNotEmpty) {
          final branchHitsMap = fileBranchHits.putIfAbsent(
            source,
            () => <int, int>{},
          );
          for (var i = 0; i < branchHitsList.length; i += 2) {
            final branchId = branchHitsList[i] as int;
            final count = branchHitsList[i + 1] as int;
            branchHitsMap[branchId] = (branchHitsMap[branchId] ?? 0) + count;
          }
        }
      }
    } catch (_) {}
  }

  final sortedSources = fileBranchHits.keys.toList()..sort();

  for (final source in sortedSources) {
    if (source.contains('/.gen/')) continue;

    final branchHits = fileBranchHits[source]!;
    final total = branchHits.length;
    final hit = branchHits.values.where((c) => c > 0).length;
    final percent = total > 0 ? (hit / total * 100) : 100.0;

    if (percent < 95.0) {
      final shortName = source.replaceFirst('package:dart_book/', '');
      print(
        '=== $shortName (${percent.toStringAsFixed(1)}% - $hit/$total branches) ===',
      );

      final lineHits = fileLineHits[source] ?? {};
      final uncoveredLines =
          lineHits.entries.where((e) => e.value == 0).map((e) => e.key).toList()
            ..sort();
      print('  Uncovered lines: $uncoveredLines');
    }
  }
}
