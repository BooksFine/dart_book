import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
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

      expect(book.metadata.id, equals('doc-guid-12345'));
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

      expect(book.content.blocks.length, equals(2)); // epigraph, section
      expect(book.content.footnotes.length, equals(1)); // footnotes properly separated
      expect(book.content.footnotes.first.id, equals('n1'));
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
      expect(book.content.footnotes.isNotEmpty, isTrue);
      expect(book.content.footnotes.first.id, equals('n1'));
    });

    test('Fb2Decoder decodes fb2.zip archives including Windows-1251 encoding', () {
      final fb2XmlHeader = '''<?xml version="1.0" encoding="windows-1251"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>Книга из ZIP архива</book-title>
    </title-info>
  </description>
  <body><p>Содержимое из FB2.ZIP</p></body>
</FictionBook>
''';

      final archiveData = _encodeWin1251(fb2XmlHeader);
      final archive = Archive()..addFile(ArchiveFile('book.fb2', archiveData.length, archiveData));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final decoder = Fb2ZipDecoder();
      expect(decoder.canDecode(zipBytes, extension: 'fb2.zip'), isTrue);

      final book = decoder.decode(zipBytes);
      expect(book.metadata.title, equals('Книга из ZIP архива'));
      expect(book.content.blocks.length, equals(1));
    });

    test('Fb2ZipEncoder and Fb2ZipConverter encode book directly into valid fb2.zip archive', () async {
      final book = Book(
        metadata: const BookMetadata(id: 'test-zip-1', title: 'Книга для FB2 ZIP', language: 'ru'),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Глава 1')],
              blocks: [BookParagraph(inlines: [BookText('Текст в архиве')])],
            ),
          ],
        ),
        resources: const [],
      );

      final encoder = Fb2ZipEncoder();
      expect(encoder.canEncode('fb2.zip'), isTrue);

      final zipBytes = await Fb2ZipConverter.bookToFb2Zip(book);
      expect(zipBytes[0] == 0x50 && zipBytes[1] == 0x4B, isTrue);

      final decodedBook = Fb2ZipConverter.fb2ZipToBook(zipBytes);
      expect(decodedBook.metadata.title, equals('Книга для FB2 ZIP'));
      expect(decodedBook.content.blocks.length, equals(2));
    });

    test('Fb2Decoder and Fb2Encoder handle custom-info info-type="sequence-url"', () async {
      final fb2Xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>Книга с URL серии</book-title>
      <sequence name="Авторская Серия" number="3"/>
    </title-info>
    <custom-info info-type="sequence-url">https://author.today/work/series/12345</custom-info>
  </description>
  <body><p>Текст</p></body>
</FictionBook>
''';

      final decoder = Fb2Decoder();
      final book = decoder.decode(Uint8List.fromList(utf8.encode(fb2Xml)));

      expect(book.metadata.series, isNotNull);
      expect(book.metadata.series!.name, equals('Авторская Серия'));
      expect(book.metadata.series!.number, equals(3));
      expect(book.metadata.series!.url, equals(Uri.parse('https://author.today/work/series/12345')));

      final encodedXml = utf8.decode(await Fb2Encoder().encode(book));
      expect(encodedXml, contains('<custom-info info-type="sequence-url">https://author.today/work/series/12345</custom-info>'));
    });
  });
}

Uint8List _encodeWin1251(String str) {
  final list = <int>[];
  for (final char in str.codeUnits) {
    if (char < 128) {
      list.add(char);
    } else if (char >= 0x0410 && char <= 0x044F) {
      list.add(char - 0x0410 + 0xC0);
    } else if (char == 0x0401) {
      list.add(0xA8);
    } else if (char == 0x0451) {
      list.add(0xB8);
    } else {
      list.add(63);
    }
  }
  return Uint8List.fromList(list);
}
