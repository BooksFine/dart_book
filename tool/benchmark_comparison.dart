import 'dart:io';
import 'package:dart_book/dart_book.dart';

void main() async {
  print(
    '═══════════════════════════════════════════════════════════════════════',
  );
  print(
    '       ПРЯМОЙ СРАВНИТЕЛЬНЫЙ БЕНЧМАРК: DART_BOOK vs EPUBX              ',
  );
  print(
    '═══════════════════════════════════════════════════════════════════════\n',
  );

  final tempDir = Directory('test/benchmarks/temp');
  if (!tempDir.existsSync()) {
    tempDir.createSync(recursive: true);
  }

  final testCases = [
    (title: 'Стандартная книга', chapters: 20, paragraphsPerChapter: 5),
    (title: 'Большая книга', chapters: 100, paragraphsPerChapter: 5),
    (title: 'Масштаб «Войны и мира»', chapters: 500, paragraphsPerChapter: 5),
  ];

  for (final tc in testCases) {
    print('📦 Подготовка книги: "${tc.title}" (${tc.chapters} глав)...');
    final builder = BookBuilder(title: tc.title);
    for (var i = 0; i < tc.chapters; i++) {
      final buffer = StringBuffer();
      for (var p = 0; p < tc.paragraphsPerChapter; p++) {
        buffer.write(
          '<p>Параграф $p главы $i с <strong>жирным</strong> текстом, <em>курсивом</em> и <a href="#ch$i">ссылкой</a>.</p>',
        );
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
    final dartBookResult = await EpubConverter.epubToBook(epubBytes);
    swDartBook.stop();

    // 2. Замер epubx (через отдельный процесс в изолированном окружении)
    final processResult = await Process.run(
      'dart',
      ['run', 'run_epubx.dart', epubFile.absolute.path],
      workingDirectory: 'test/benchmarks/epubx_runner',
      runInShell: true,
    );

    int epubxMs = -1;
    int epubxChapters = 0;
    final stdoutStr = processResult.stdout as String;
    final stderrStr = processResult.stderr as String;

    if (stderrStr.isNotEmpty && processResult.exitCode != 0) {
      print('   ⚠️ Ошибка epubx: $stderrStr');
    }

    for (final line in stdoutStr.split('\n')) {
      if (line.startsWith('EPUBX_RESULT:')) {
        final parts = line.trim().substring('EPUBX_RESULT:'.length).split(':');
        epubxMs = int.parse(parts[0]);
        epubxChapters = int.parse(parts[1]);
      }
    }

    print('📊 Результаты для ${tc.chapters} глав:');
    print(
      '   ├─ dart_book: ${swDartBook.elapsedMilliseconds} ms (${dartBookResult.content.blocks.length} глав)',
    );
    print('   ├─ epubx:     $epubxMs ms ($epubxChapters глав)');
    if (epubxMs > 0 && swDartBook.elapsedMilliseconds > 0) {
      final speedup = epubxMs / swDartBook.elapsedMilliseconds;
      print(
        '   └─ Разница:   dart_book быстрее в ${speedup.toStringAsFixed(2)}x раз!',
      );
    }
    print('');
  }

  // Очистка
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
  print(
    '═══════════════════════════════════════════════════════════════════════',
  );
}
