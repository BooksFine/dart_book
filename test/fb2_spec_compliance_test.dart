import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('FB2 2.2 Spec Compliance Tests', () {
    test('Fb2Decoder extracts full FB2 2.2 metadata: cover, genres, annotation, series, keywords', () {
      final fb2Xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>sf_fantasy</genre>
      <genre>detective</genre>
      <book-title>Тестовая Книга FB2 2.2</book-title>
      <annotation><p>Аннотация к книге</p></annotation>
      <keywords>фантастика, детектив, космос</keywords>
      <coverpage><image l:href="#cover.jpg"/></coverpage>
      <lang>ru</lang>
      <sequence name="Космическая Одиссея" number="1"/>
    </title-info>
    <document-info>
      <id>doc-guid-12345</id>
    </document-info>
  </description>
  <body><p>Основное тело книги</p></body>
  <binary id="cover.jpg" content-type="image/jpeg">aW1hZ2UtYnl0ZXM=</binary>
</FictionBook>
''';

      final decoder = Fb2Decoder();
      final book = decoder.decode(Uint8List.fromList(utf8.encode(fb2Xml)));

      expect(book.id, equals('doc-guid-12345'));
      expect(book.metadata.title, equals('Тестовая Книга FB2 2.2'));
      expect(book.metadata.language, equals('ru'));
      expect(book.metadata.genres.length, equals(2));
      expect(book.metadata.genres.first.code, equals('sf_fantasy'));
      expect(book.metadata.annotation, isNotNull);
      expect(book.metadata.cover, isNotNull);
      expect(book.metadata.cover!.ref.id, equals('cover.jpg'));
      expect(book.metadata.series, isNotNull);
      expect(book.metadata.series!.name, equals('Космическая Одиссея'));
      expect(book.metadata.series!.number, equals(1));
      expect(book.metadata.keywords, contains('детектив'));
    });

    test('Fb2Parser parses epigraphs, sub, sup, strike, code, and footnote links', () {
      final fb2Xml = '''
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <body>
    <epigraph>
      <p>Цитата эпиграфа</p>
      <text-author>Автор Эпиграфа</text-author>
    </epigraph>
    <section>
      <p>Текст с <sub>подстрочным</sub>, <sup>надстрочным</sup>, <strikethrough>зачеркнутым</strikethrough> и <code>кодом</code>.</p>
      <p>Ссылка на сноску <a type="note" l:href="#n1">[1]</a>.</p>
    </section>
  </body>
  <body name="notes">
    <section id="n1">
      <title><p>1</p></title>
      <p>Текст сноски №1</p>
    </section>
  </body>
</FictionBook>
''';

      final decoder = Fb2Decoder();
      final book = decoder.decode(Uint8List.fromList(utf8.encode(fb2Xml)));

      expect(book.content.blocks.length, equals(3)); // epigraph, section, notes section
      expect(book.content.blocks[0], isA<BookQuote>());

      final quote = book.content.blocks[0] as BookQuote;
      expect(quote.citation.first, isA<BookText>());
      expect((quote.citation.first as BookText).text, equals('Автор Эпиграфа'));

      final section = book.content.blocks[1] as BookSection;
      final paragraph = section.blocks[0] as BookParagraph;
      expect(paragraph.inlines.any((i) => i is BookSubscript), isTrue);
      expect(paragraph.inlines.any((i) => i is BookSuperscript), isTrue);
      expect(paragraph.inlines.any((i) => i is BookStrike), isTrue);
      expect(paragraph.inlines.any((i) => i is BookCodeSpan), isTrue);

      final fnParagraph = section.blocks[1] as BookParagraph;
      expect(fnParagraph.inlines.any((i) => i is BookFootnoteRef), isTrue);
      final fnRef = fnParagraph.inlines.firstWhere((i) => i is BookFootnoteRef) as BookFootnoteRef;
      expect(fnRef.id, equals('n1'));

      // Проверяем наличие тела сносок
      final notesSection = book.content.blocks[2] as BookSection;
      expect(notesSection.id, equals('notes'));
    });
  });
}
