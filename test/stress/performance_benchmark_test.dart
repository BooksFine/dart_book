import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Stress & Performance Benchmark Tests', () {
    test('HtmlParser: Measures parser performance on 10,000 paragraphs', () {
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
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('Fb2Decoder: Measures parsing performance on 5,000 sections', () {
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

    test('War & Peace Scale: Measures Roundtrip conversion performance on 1,000 chapters and 10,000 paragraphs', () async {
      final builder = BookBuilder(title: 'Война и мир (Масштабный бенчмарк)');
      for (var i = 0; i < 1000; i++) {
        final chapterHtml = '''
          <p>Параграф 1 главы $i: Князь Андрей Болконский ехал в имение Отрадное.</p>
          <p>Параграф 2 главы $i: На краю дороги стоял дуб. Вероятно, в десять раз старее берез.</p>
          <p>Параграф 3 главы $i: Старый дуб, весь преображенный, раскинувшись шатром сочной зелени, млел в лучах вечернего солнца.</p>
          <p>Параграф 4 главы $i: «Нет, жизнь не кончена в тридцать один год», — вдруг окончательно решил князь Андрей.</p>
          <p>Параграф 5 главы $i: Пьер Безухов в это время беседовал с масонами в Петербурге.</p>
          <p>Параграф 6 главы $i: Наташа Ростова пела у открытого окна верхнего этажа.</p>
          <p>Параграф 7 главы $i: Бородинское сражение разворачивалось на рассвете.</p>
          <p>Параграф 8 главы $i: Кутузов сидел на складном стуле и внимательно слушал донесения адъютантов.</p>
          <p>Параграф 9 главы $i: Первый залп батареи Раевского потряс окрестности.</p>
          <p>Параграф 10 главы $i: Вечернее солнце озаряло поле битвы золотым сиянием.</p>
        ''';
        await builder.addChapterHtml(chapterHtml, title: 'Том I, Глава $i');
      }
      final book = await builder.build();
      expect(book.content.blocks.length, equals(1000));

      // 1. FB2 Encoder & Decoder
      final stopFb2Enc = Stopwatch()..start();
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      stopFb2Enc.stop();
      print('[BENCHMARK] Fb2Encoder 1,000 chapters (10,000 paragraphs): ${stopFb2Enc.elapsedMilliseconds} ms (${fb2Bytes.length} bytes)');

      final stopFb2Dec = Stopwatch()..start();
      final decodedFb2 = Fb2Converter.fb2ToBook(fb2Bytes);
      stopFb2Dec.stop();
      print('[BENCHMARK] Fb2Decoder 1,000 chapters (10,000 paragraphs): ${stopFb2Dec.elapsedMilliseconds} ms');

      expect(decodedFb2.content.blocks.length, equals(1000));
      expect(stopFb2Enc.elapsedMilliseconds, lessThan(3000));
      expect(stopFb2Dec.elapsedMilliseconds, lessThan(3000));

      // 2. EPUB Encoder & Decoder
      final stopEpubEnc = Stopwatch()..start();
      final epubBytes = await EpubConverter.bookToEpub(book);
      stopEpubEnc.stop();
      print('[BENCHMARK] EpubEncoder 1,000 chapters (10,000 paragraphs): ${stopEpubEnc.elapsedMilliseconds} ms (${epubBytes.length} bytes)');

      final stopEpubDec = Stopwatch()..start();
      final decodedEpub = await EpubConverter.epubToBook(epubBytes);
      stopEpubDec.stop();
      print('[BENCHMARK] EpubDecoder 1,000 chapters (10,000 paragraphs): ${stopEpubDec.elapsedMilliseconds} ms');

      expect(decodedEpub.content.blocks.length, equals(1000));
      expect(stopEpubEnc.elapsedMilliseconds, lessThan(3000));
      expect(stopEpubDec.elapsedMilliseconds, lessThan(3000));
    });

    test('Isolates: Verifies 144 FPS non-blocking execution with DartBook.loadIsolated and DartBook.encodeIsolated', () async {
      final builder = BookBuilder(title: 'Изолированная книга 144 FPS');
      for (var i = 0; i < 50; i++) {
        await builder.addChapterHtml('<p>Параграф $i для изолята</p>', title: 'Глава $i');
      }
      final book = await builder.build();

      // 1. encodeIsolated (FB2)
      final fb2Bytes = await DartBook.encodeIsolated(book, 'fb2');
      expect(fb2Bytes, isNotEmpty);

      // 2. loadIsolated (FB2)
      final loadedFb2 = await DartBook.loadIsolated(fb2Bytes, filename: 'book.fb2');
      expect(loadedFb2.metadata.title, equals('Изолированная книга 144 FPS'));
      expect(loadedFb2.content.blocks.length, equals(50));

      // 3. encodeIsolated (EPUB)
      final epubBytes = await DartBook.encodeIsolated(book, 'epub');
      expect(epubBytes, isNotEmpty);

      // 4. loadIsolated (EPUB)
      final loadedEpub = await DartBook.loadIsolated(epubBytes, filename: 'book.epub');
      expect(loadedEpub.metadata.title, equals('Изолированная книга 144 FPS'));
      expect(loadedEpub.content.blocks.length, equals(50));
    });
  });
}
