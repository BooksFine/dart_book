import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  print('════════════════════════════════════════════════════════════════════════════════════════');
  print('       ЧЕСТНЫЙ ЭМПИРИЧЕСКИЙ БЕНЧМАРК: DART_BOOK vs EPUBX vs EPUB_PLUS vs EPUB_PRO       ');
  print('════════════════════════════════════════════════════════════════════════════════════════\n');

  final tempDir = Directory('tool/benchmarks/temp');
  if (!tempDir.existsSync()) {
    tempDir.createSync(recursive: true);
  }


  final testCases = [
    (title: 'Стандартная книга', chapters: 20, paragraphsPerChapter: 5),
    (title: 'Большая книга', chapters: 100, paragraphsPerChapter: 5),
    (title: 'Масштаб «Войны и мира»', chapters: 500, paragraphsPerChapter: 5),
  ];

  for (final tc in testCases) {
    print('📦 Тестовый сценарий: "${tc.title}" (${tc.chapters} глав)...');
    final builder = BookBuilder(title: tc.title);
    for (var i = 0; i < tc.chapters; i++) {
      final buffer = StringBuffer();
      for (var p = 0; p < tc.paragraphsPerChapter; p++) {
        buffer.write('<p>Параграф $p главы $i с <strong>жирным</strong> текстом, <em>курсивом</em> и <a href="#ch$i">ссылкой</a>.</p>');
      }
      await builder.addChapterHtml(buffer.toString(), title: 'Глава $i');
    }
    final book = await builder.build();
    final epubBytes = await EpubConverter.bookToEpub(book);

    final epubFile = File('${tempDir.path}/test_${tc.chapters}.epub');
    await epubFile.writeAsBytes(epubBytes);

    // 1. Замер dart_book (с прогревом JIT)
    await EpubConverter.epubToBook(epubBytes); // прогрев
    final swDartBook = Stopwatch()..start();
    await EpubConverter.epubToBook(epubBytes);
    swDartBook.stop();

    // 2. Замер epubx
    int epubxMs = -1;
    try {
      final res = await Process.run(

        'dart',
        ['run', 'run_epubx.dart', epubFile.absolute.path],
        workingDirectory: 'tool/benchmarks/epubx_runner',
        runInShell: true,
      );
      for (final line in (res.stdout as String).split('\n')) {
        if (line.startsWith('EPUBX_RESULT:')) {
          final parts = line.trim().substring('EPUBX_RESULT:'.length).split(':');
          epubxMs = int.parse(parts[0]);
        }
      }
    } catch (_) {}

    // 3. Замер epub_plus и epub_pro
    int epubPlusMs = -1;
    int epubPlusDomMs = -1;
    int epubProMs = -1;
    int epubProDomMs = -1;
    try {
      final res = await Process.run(
        'dart',
        ['run', 'bin/benchmark_all.dart', epubFile.absolute.path],
        workingDirectory: 'tool/benchmarks/competitors',
        runInShell: true,
      );

      for (final line in (res.stdout as String).split('\n')) {
        if (line.startsWith('EPUB_PLUS_RESULT:')) {
          epubPlusMs = int.parse(line.trim().substring('EPUB_PLUS_RESULT:'.length).split(':')[0]);
        }
        if (line.startsWith('EPUB_PLUS_FULL_DOM_RESULT:')) {
          epubPlusDomMs = int.parse(line.trim().substring('EPUB_PLUS_FULL_DOM_RESULT:'.length).split(':')[0]);
        }
        if (line.startsWith('EPUB_PRO_RESULT:')) {
          epubProMs = int.parse(line.trim().substring('EPUB_PRO_RESULT:'.length).split(':')[0]);
        }
        if (line.startsWith('EPUB_PRO_FULL_DOM_RESULT:')) {
          epubProDomMs = int.parse(line.trim().substring('EPUB_PRO_FULL_DOM_RESULT:'.length).split(':')[0]);
        }
      }
    } catch (_) {}

    print('📊 Реальные замеры для ${tc.chapters} глав:');
    print('   А. Поверхностное чтение манифеста (только распаковка строк):');
    print('      ├─ epubx:     ${epubxMs.toString().padLeft(4)} ms');
    print('      ├─ epub_plus: ${epubPlusMs.toString().padLeft(4)} ms');
    print('      └─ epub_pro:  ${epubProMs.toString().padLeft(4)} ms');
    print('   Б. Полная готовность контента к отображению (парсинг HTML/AST):');
    print('      ├─ dart_book (полный AST 23 узла):  ${swDartBook.elapsedMilliseconds.toString().padLeft(4)} ms');
    print('      ├─ epub_plus + html.parse:          ${epubPlusDomMs.toString().padLeft(4)} ms');
    print('      └─ epub_pro + html.parse:           ${epubProDomMs.toString().padLeft(4)} ms');
    print('');
  }

  // Очистка
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
  print('════════════════════════════════════════════════════════════════════════════════════════');
}
