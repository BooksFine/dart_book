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
      expect(decodedBook.content.blocks.length, equals(1));
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

    test('FB2 Roundtrip: Full lossless roundtrip of footnotes, epigraphs, author contacts and dates', () async {
      final originalBook = Book(
        metadata: BookMetadata(
          id: 'fb2-full-roundtrip-1',
          title: 'Полный Тест Раундтрипа FB2',
          language: 'ru',
          publishedAt: DateTime(2024, 8, 15),
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: const PersonName(
                first: 'Александр',
                middle: 'Сергеевич',
                last: 'Пушкин',
                nickname: 'АСП',
                display: 'Александр Сергеевич Пушкин',
              ),
              email: 'pushkin@litera.ru',
              homePage: Uri.parse('https://pushkin.ru'),
            ),
            BookContributor(
              role: BookContributorRole.translator,
              name: const PersonName(
                first: 'Владимир',
                last: 'Набоков',
                display: 'Владимир Набоков',
              ),
              email: 'nabokov@cornell.edu',
              homePage: Uri.parse('https://nabokov.org'),
            ),
          ],
          genres: const [BookGenre(code: 'poetry', name: 'poetry')],
          keywords: const ['поэзия', 'классика'],
        ),
        content: const BookContent(
          blocks: [
            BookQuote(
              blocks: [BookParagraph(inlines: [BookText('В начале было Слово...')])],
              citation: [BookText('Евангелие')],
              attributes: {'fb2-type': 'epigraph'},
            ),
            BookQuote(
              blocks: [BookParagraph(inlines: [BookText('Обычная цитата внутри текста')])],
              citation: [BookText('Автор Цитаты')],
            ),
            BookSection(
              title: [BookText('Глава 1')],
              blocks: [
                BookParagraph(inlines: [
                  BookText('Текст первого абзаца со ссылкой на сноску '),
                  BookFootnoteRef(id: 'note_1', label: [BookText('[1]')]),
                  BookText('.'),
                ]),
              ],
            ),
          ],
          footnotes: [
            BookFootnote(
              id: 'note_1',
              blocks: [
                BookParagraph(inlines: [BookText('Текст первой сноски.')]),
              ],
            ),
          ],
        ),
        resources: const [],
      );

      final encoder = Fb2Encoder();
      final decoder = Fb2Decoder();

      // Round 1: Book -> FB2 XML
      final fb2Bytes1 = await encoder.encode(originalBook);
      final fb2Xml1 = utf8.decode(fb2Bytes1);

      // Verify strict schema ordering in XML output:
      // <book-title> -> <annotation> -> <keywords> -> <date> -> <coverpage> -> <lang> -> <translator>
      final titlePos = fb2Xml1.indexOf('<book-title>');
      final datePos = fb2Xml1.indexOf('<date');
      final langPos = fb2Xml1.indexOf('<lang>');
      final translatorPos = fb2Xml1.indexOf('<translator>');
      expect(titlePos < datePos, isTrue);
      expect(datePos < langPos, isTrue);
      expect(langPos < translatorPos, isTrue);

      // Verify specific tags in XML
      expect(fb2Xml1, contains('<epigraph>'));
      expect(fb2Xml1, contains('<cite>'));
      expect(fb2Xml1, contains('<body name="notes">'));
      expect(fb2Xml1, contains('email>pushkin@litera.ru<'));
      expect(fb2Xml1, contains('home-page>https://pushkin.ru<'));
      expect(fb2Xml1, contains('email>nabokov@cornell.edu<'));
      expect(fb2Xml1, contains('value="2024-08-15"'));

      // Decode Round 1
      final decodedBook1 = decoder.decode(fb2Bytes1);

      // Verify metadata
      expect(decodedBook1.metadata.title, equals('Полный Тест Раундтрипа FB2'));
      expect(decodedBook1.metadata.language, equals('ru'));
      expect(decodedBook1.metadata.publishedAt, equals(DateTime(2024, 8, 15)));

      // Verify author
      final author = decodedBook1.metadata.contributorsByRole(BookContributorRole.author).first;
      expect(author.name.first, equals('Александр'));
      expect(author.name.middle, equals('Сергеевич'));
      expect(author.name.last, equals('Пушкин'));
      expect(author.name.nickname, equals('АСП'));
      expect(author.name.toDisplayString(), equals('Александр Сергеевич Пушкин'));
      expect(author.email, equals('pushkin@litera.ru'));
      expect(author.homePage, equals(Uri.parse('https://pushkin.ru')));

      // Verify translator
      final translator = decodedBook1.metadata.contributorsByRole(BookContributorRole.translator).first;
      expect(translator.name.first, equals('Владимир'));
      expect(translator.name.last, equals('Набоков'));
      expect(translator.name.toDisplayString(), equals('Владимир Набоков'));
      expect(translator.email, equals('nabokov@cornell.edu'));
      expect(translator.homePage, equals(Uri.parse('https://nabokov.org')));

      // Verify content blocks: epigraph vs quote
      expect(decodedBook1.content.blocks.length, equals(3));
      final epigraph = decodedBook1.content.blocks[0] as BookQuote;
      expect(epigraph.attributes['fb2-type'], equals('epigraph'));
      final quote = decodedBook1.content.blocks[1] as BookQuote;
      expect(quote.attributes['fb2-type'], isNot(equals('epigraph')));

      // Verify footnotes
      expect(decodedBook1.content.footnotes.length, equals(1));
      expect(decodedBook1.content.footnotes.first.id, equals('note_1'));
      expect(decodedBook1.content.footnotes.first.blocks.length, equals(1));
      final fnParagraph = decodedBook1.content.footnotes.first.blocks.first as BookParagraph;
      expect((fnParagraph.inlines.first as BookText).text, equals('Текст первой сноски.'));

      // Round 2: Re-encode and re-decode (confirming stability and no accumulation)
      final fb2Bytes2 = await encoder.encode(decodedBook1);
      final decodedBook2 = decoder.decode(fb2Bytes2);

      expect(decodedBook2.content.blocks.length, equals(3));
      expect(decodedBook2.content.footnotes.length, equals(1));
      expect(decodedBook2.content.footnotes.first.blocks.length, equals(1));
      expect(decodedBook2.metadata.contributors.length, equals(2));
      expect(decodedBook2.metadata.publishedAt, equals(DateTime(2024, 8, 15)));
    });

    test('FB2 2.1: Roundtrip encoding & decoding for code, sub, sup, strikethrough and table rowspan/colspan', () async {
      final xmlInput = '''
<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>FB2 2.1 Feature Test</book-title>
    </title-info>
  </description>
  <body>
    <section>
      <p>Inline tags: <code>final x = 10;</code>, <sub>H2O</sub>, <sup>E=mc2</sup>, <strikethrough>old text</strikethrough>.</p>
      <table>
        <tr>
          <th colspan="2" rowspan="1"><p>Header spanning 2 columns</p></th>
          <th rowspan="2"><p>Header spanning 2 rows</p></th>
        </tr>
        <tr>
          <td><p>Cell 1</p></td>
          <td><p>Cell 2</p></td>
        </tr>
      </table>
    </section>
  </body>
</FictionBook>
''';

      final decoder = Fb2Decoder();
      final book = decoder.decode(Uint8List.fromList(utf8.encode(xmlInput)));

      final section = book.content.blocks.first as BookSection;
      final paragraph = section.blocks[0] as BookParagraph;

      // Verify inline AST
      expect(paragraph.inlines.any((i) => i is BookCodeSpan && i.code == 'final x = 10;'), isTrue);
      expect(paragraph.inlines.any((i) => i is BookSubscript), isTrue);
      expect(paragraph.inlines.any((i) => i is BookSuperscript), isTrue);
      expect(paragraph.inlines.any((i) => i is BookStrike), isTrue);

      // Verify table AST
      final table = section.blocks[1] as BookTable;
      expect(table.rows.length, equals(2));
      expect(table.rows[0].cells.length, equals(2));
      expect(table.rows[0].cells[0].colSpan, equals(2));
      expect(table.rows[0].cells[0].rowSpan, isNull); // 1 is normalized to null
      expect(table.rows[0].cells[1].colSpan, isNull);
      expect(table.rows[0].cells[1].rowSpan, equals(2));

      // Test encoder roundtrip
      final encoder = Fb2Encoder();
      final encodedBytes = await encoder.encode(book);
      final encodedXml = utf8.decode(encodedBytes);

      expect(encodedXml, contains('<code>final x = 10;</code>'));
      expect(encodedXml, contains('<sub>'));
      expect(encodedXml, contains('<sup>'));
      expect(encodedXml, contains('<strikethrough>'));
      expect(encodedXml, contains('colspan="2"'));
      expect(encodedXml, contains('rowspan="2"'));

      // Re-decode encoded XML and verify AST preservation
      final roundtripBook = decoder.decode(encodedBytes);
      final rtSection = roundtripBook.content.blocks.firstWhere((b) => b is BookSection) as BookSection;
      final rtParagraph = rtSection.blocks[0] as BookParagraph;
      expect(rtParagraph.inlines.any((i) => i is BookCodeSpan && i.code == 'final x = 10;'), isTrue);
      expect(rtParagraph.inlines.any((i) => i is BookSubscript), isTrue);
      expect(rtParagraph.inlines.any((i) => i is BookSuperscript), isTrue);
      expect(rtParagraph.inlines.any((i) => i is BookStrike), isTrue);

      final rtTable = rtSection.blocks[1] as BookTable;
      expect(rtTable.rows[0].cells[0].colSpan, equals(2));
      expect(rtTable.rows[0].cells[1].rowSpan, equals(2));
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
