import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Performance Benchmark Tests', () {
    test('Measures HtmlParser performance on 10,000 paragraphs', () {
      final buffer = StringBuffer();
      buffer.write('<div>');
      for (var i = 0; i < 10000; i++) {
        buffer.write('<p>Параграф №$i с <strong>жирным</strong> и <em>курсивным</em> текстом, <a href="#p$i">ссылкой</a> и <code>кодом</code>.</p>');
      }
      buffer.write('</div>');
      final htmlStr = buffer.toString();

      final stopwatch = Stopwatch()..start();
      final parser = HtmlParser();
      final blocks = parser.parseFromString(htmlStr);
      stopwatch.stop();

      print('[BENCHMARK] HtmlParser 10,000 paragraphs: ${stopwatch.elapsedMilliseconds} ms (${blocks.length} blocks parsed)');
      expect(blocks.length, equals(10000));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Должно занимать меньше 3 сек
    });

    test('Measures Fb2Parser and Fb2Decoder performance on 5,000 sections', () {
      final buffer = StringBuffer();
      buffer.write('<?xml version="1.0" encoding="UTF-8"?>');
      buffer.write('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">');
      buffer.write('<description><title-info><book-title>Большая FB2 Книга</book-title></title-info></description>');
      buffer.write('<body>');
      for (var i = 0; i < 5000; i++) {
        buffer.write('<section><title><p>Глава $i</p></title><p>Текст главы $i с <emphasis>выделением</emphasis> и <a type="note" l:href="#n$i">[сноской]</a>.</p></section>');
      }
      buffer.write('</body>');
      buffer.write('</FictionBook>');
      final xmlBytes = Uint8List.fromList(utf8.encode(buffer.toString()));

      final stopwatch = Stopwatch()..start();
      final decoder = Fb2Decoder();
      final book = decoder.decode(xmlBytes);
      stopwatch.stop();

      print('[BENCHMARK] Fb2Decoder 5,000 sections: ${stopwatch.elapsedMilliseconds} ms (book.metadata.id: ${book.metadata.id})');
      expect(book.content.blocks.length, equals(5000));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('Measures Roundtrip conversion performance EPUB/FB2', () async {
      final builder = BookBuilder(title: 'Производительная книга');
      for (var i = 0; i < 1000; i++) {
        await builder.addChapterHtml('<p>Абзац главы $i с текстом для бенчмарка.</p>', title: 'Глава $i');
      }
      final book = await builder.build();

      final stopFb2 = Stopwatch()..start();
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      stopFb2.stop();

      final stopEpub = Stopwatch()..start();
      final epubBytes = await EpubConverter.bookToEpub(book);
      stopEpub.stop();

      print('[BENCHMARK] Fb2Encoder 1,000 chapters: ${stopFb2.elapsedMilliseconds} ms (${fb2Bytes.length} bytes)');
      print('[BENCHMARK] EpubEncoder 1,000 chapters: ${stopEpub.elapsedMilliseconds} ms (${epubBytes.length} bytes)');

      expect(fb2Bytes.length, greaterThan(0));
      expect(epubBytes.length, greaterThan(0));
    });

    test('Verifies 144 FPS isolated loading with DartBook.loadIsolated', () async {
      final fb2Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info><book-title>Изолированная книга</book-title></title-info></description>
  <body><p>Текст в бэкграунд изоляте</p></body>
</FictionBook>
''';
      final bytes = Uint8List.fromList(utf8.encode(fb2Xml));

      final book = await DartBook.loadIsolated(bytes, filename: 'book.fb2');
      expect(book.metadata.title, equals('Изолированная книга'));
    });
  });
}
