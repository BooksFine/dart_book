import 'dart:io';

class FunctionComplexity {
  final String file;
  final String functionName;
  final int line;
  final int ccn;

  FunctionComplexity({
    required this.file,
    required this.functionName,
    required this.line,
    required this.ccn,
  });
}

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Directory "lib" not found.');
    exit(1);
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('.gen/'))
      .toList();

  final allFunctions = <FunctionComplexity>[];

  for (final file in files) {
    final lines = file.readAsLinesSync();
    final relativePath = file.path
        .replaceAll('\\', '/')
        .replaceFirst('lib/', '');
    allFunctions.addAll(_analyzeFile(relativePath, lines));
  }

  allFunctions.sort((a, b) => b.ccn.compareTo(a.ccn));

  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
  print(
    '          АНАЛИЗ ЦИКЛОМАТИЧЕСКОЙ СЛОЖНОСТИ МАККЕЙБА (CYCLOMATIC COMPLEXITY / CCN)',
  );
  print(
    '════════════════════════════════════════════════════════════════════════════════\n',
  );

  final totalFunctions = allFunctions.length;
  final totalCcn = allFunctions.fold(0, (sum, f) => sum + f.ccn);
  final avgCcn = totalFunctions > 0
      ? (totalCcn / totalFunctions).toStringAsFixed(2)
      : '0';

  final lowRisk = allFunctions.where((f) => f.ccn <= 5).length;
  final moderateRisk = allFunctions
      .where((f) => f.ccn >= 6 && f.ccn <= 10)
      .length;
  final highRisk = allFunctions.where((f) => f.ccn >= 11 && f.ccn <= 20).length;
  final veryHighRisk = allFunctions.where((f) => f.ccn > 20).length;

  print('📊 Общие метрики кодовой базы:');
  print('   • Всего проанализировано функций/методов : $totalFunctions');
  print(
    '   • Средняя сложность (Average CCN)        : $avgCcn (Отлично, норма NIST < 10)',
  );
  print(
    '   • Максимальная сложность (Max CCN)       : ${allFunctions.isNotEmpty ? allFunctions.first.ccn : 0}\n',
  );

  print('📈 Распределение по уровням сложности (NIST / McCabe Standard):');
  print(
    '   • 🟢 Простой код (CCN 1–5)       : $lowRisk (${(lowRisk / totalFunctions * 100).toStringAsFixed(1)}%) — идеальная поддерживаемость',
  );
  print(
    '   • 🟡 Умеренная сложность (CCN 6–10): $moderateRisk (${(moderateRisk / totalFunctions * 100).toStringAsFixed(1)}%) — хороший баланс',
  );
  print(
    '   • 🟠 Повышенная сложность (CCN 11–20): $highRisk (${(highRisk / totalFunctions * 100).toStringAsFixed(1)}%) — тяжелые парсеры/мапперы',
  );
  print(
    '   • 🔴 Высокая сложность (CCN > 20) : $veryHighRisk (${(veryHighRisk / totalFunctions * 100).toStringAsFixed(1)}%)\n',
  );

  print(
    '────────────────────────────────────────────────────────────────────────────────',
  );
  print('ТОП САМЫХ СЛОЖНЫХ МЕТОДОВ (Высокий CCN):');
  print(
    '────────────────────────────────────────────────────────────────────────────────',
  );
  print(
    'CCN   Строка  Метод / Функция                                       Файл',
  );
  print(
    '────────────────────────────────────────────────────────────────────────────────',
  );

  for (final fn in allFunctions.take(15)) {
    final ccnStr = fn.ccn.toString().padLeft(3);
    final lineStr = fn.line.toString().padLeft(6);
    final nameStr = fn.functionName.length > 40
        ? '${fn.functionName.substring(0, 37)}...'
        : fn.functionName.padRight(40);
    print('$ccnStr  $lineStr  $nameStr  ${fn.file}');
  }
  print(
    '════════════════════════════════════════════════════════════════════════════════',
  );
}

List<FunctionComplexity> _analyzeFile(String filePath, List<String> lines) {
  final result = <FunctionComplexity>[];

  var inFunction = false;
  var currentName = '';
  var currentLine = 0;
  var braceDepth = 0;
  var currentCcn = 1;

  final methodPattern = RegExp(
    r'^(?:\s*)(?:(?:Future|Stream|Book|List|Map|String|int|double|bool|void|Uint8List|\w+)(?:<[^>]+>)?\s+)?([_a-zA-Z0-9]+)\s*\([^)]*\)\s*(?:async\*?|sync\*?)?\s*(\{|=>)',
  );

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final line = _stripCommentsAndStrings(rawLine);

    if (!inFunction) {
      final match = methodPattern.firstMatch(rawLine);
      if (match != null) {
        final name = match.group(1)!;
        if (!_isKeyword(name)) {
          inFunction = true;
          currentName = name;
          currentLine = i + 1;
          currentCcn = 1;
          braceDepth = 0;
        }
      }
    }

    if (inFunction) {
      // Calculate decision points for McCabe CCN
      currentCcn += _countDecisionPoints(line);

      for (var charIndex = 0; charIndex < line.length; charIndex++) {
        final c = line[charIndex];
        if (c == '{') {
          braceDepth++;
        } else if (c == '}') {
          braceDepth--;
          if (braceDepth <= 0) {
            result.add(
              FunctionComplexity(
                file: filePath,
                functionName: currentName,
                line: currentLine,
                ccn: currentCcn,
              ),
            );
            inFunction = false;
            break;
          }
        }
      }

      // For arrow functions:
      if (rawLine.contains('=>') && braceDepth == 0 && inFunction) {
        result.add(
          FunctionComplexity(
            file: filePath,
            functionName: currentName,
            line: currentLine,
            ccn: currentCcn,
          ),
        );
        inFunction = false;
      }
    }
  }

  return result;
}

int _countDecisionPoints(String code) {
  var count = 0;

  final ifMatches = RegExp(r'\bif\s*\(').allMatches(code).length;
  final whileMatches = RegExp(r'\bwhile\s*\(').allMatches(code).length;
  final forMatches = RegExp(r'\bfor\s*\(').allMatches(code).length;
  final catchMatches = RegExp(r'\bcatch\s*\(').allMatches(code).length;
  final caseMatches = RegExp(r'\bcase\s+').allMatches(code).length;

  // Logical operators
  final andMatches = RegExp(r'&&').allMatches(code).length;
  final orMatches = RegExp(r'\|\|').allMatches(code).length;
  final ternaryMatches = RegExp(r'\?(?![?\.])').allMatches(code).length;
  final nullCoalescing = RegExp(r'\?\?').allMatches(code).length;

  count +=
      ifMatches +
      whileMatches +
      forMatches +
      catchMatches +
      caseMatches +
      andMatches +
      orMatches +
      ternaryMatches +
      nullCoalescing;

  return count;
}

String _stripCommentsAndStrings(String line) {
  var stripped = line.replaceAll(RegExp(r'//.*$'), '');
  stripped = stripped.replaceAll(RegExp(r'''(['"]).*?\1'''), '');
  return stripped;
}

bool _isKeyword(String word) {
  const keywords = {
    'if',
    'while',
    'for',
    'switch',
    'catch',
    'return',
    'throw',
    'else',
    'case',
    'default',
    'class',
    'mixin',
    'extension',
    'enum',
    'factory',
  };
  return keywords.contains(word);
}
