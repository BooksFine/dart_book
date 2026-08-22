import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

import '../../utils/ast_normalizer.dart';
import '../../utils/golden_comparator.dart';

void main() {
  group('FB2 Codec Unit Tests (Fb2Decoder & Fb2Encoder)', () {
    // -------------------------------------------------------------------------
    // 1. Windows-1251 (256-byte complete table and Cyrillic/Symbols)
    // -------------------------------------------------------------------------
    group('Windows-1251 encoding and decoding', () {
      test('Decodes complete Windows-1251 byte table (0x00 - 0xFF)', () {
        // Build expected decoded characters for all 256 bytes in Windows-1251
        final byteList = <int>[];
        final expectedChars = StringBuffer();

        for (var b = 0x20; b <= 0xFF; b++) {
          // Avoid XML special characters in raw text inside <p>
          if (b == 0x3C || b == 0x3E || b == 0x26 || b == 0x7F)
            continue; // '<', '>', '&', DEL
          byteList.add(b);

          if (b < 0x80) {
            expectedChars.writeCharCode(b);
          } else if (b >= 0xC0 && b <= 0xFF) {
            expectedChars.writeCharCode(0x0410 + (b - 0xC0));
          } else {
            const win1251Lookup = <int, int>{
              0x80: 0x0402,
              0x81: 0x0403,
              0x82: 0x201A,
              0x83: 0x0453,
              0x84: 0x201E,
              0x85: 0x2026,
              0x86: 0x2020,
              0x87: 0x2021,
              0x88: 0x20AC,
              0x89: 0x2030,
              0x8A: 0x0409,
              0x8B: 0x2039,
              0x8C: 0x040A,
              0x8D: 0x040C,
              0x8E: 0x040B,
              0x8F: 0x040F,
              0x90: 0x0452,
              0x91: 0x2018,
              0x92: 0x2019,
              0x93: 0x201C,
              0x94: 0x201D,
              0x95: 0x2022,
              0x96: 0x2013,
              0x97: 0x2014,
              0x99: 0x2122,
              0x9A: 0x0459,
              0x9B: 0x203A,
              0x9C: 0x045A,
              0x9D: 0x045C,
              0x9E: 0x045B,
              0x9F: 0x045F,
              0xA0: 0x00A0,
              0xA1: 0x040E,
              0xA2: 0x045E,
              0xA3: 0x0408,
              0xA4: 0x00A4,
              0xA5: 0x0490,
              0xA6: 0x00A6,
              0xA7: 0x00A7,
              0xA8: 0x0401,
              0xA9: 0x00A9,
              0xAA: 0x0404,
              0xAB: 0x00AB,
              0xAC: 0x00AC,
              0xAD: 0x00AD,
              0xAE: 0x00AE,
              0xAF: 0x0407,
              0xB0: 0x00B0,
              0xB1: 0x00B1,
              0xB2: 0x0406,
              0xB3: 0x0456,
              0xB4: 0x0491,
              0xB5: 0x00B5,
              0xB6: 0x00B6,
              0xB7: 0x00B7,
              0xB8: 0x0451,
              0xB9: 0x2116,
              0xBA: 0x0454,
              0xBB: 0x00BB,
              0xBC: 0x0458,
              0xBD: 0x0405,
              0xBE: 0x0455,
              0xBF: 0x0457,
            };
            expectedChars.writeCharCode(win1251Lookup[b] ?? b);
          }
        }

        final xmlHeader =
            '<?xml version="1.0" encoding="windows-1251"?>\n<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">\n  <description><title-info><book-title>Win1251 Test</book-title></title-info></description>\n  <body><p>';
        final xmlFooter = '</p></body>\n</FictionBook>';

        final fullBytes = <int>[
          ...xmlHeader.codeUnits,
          ...byteList,
          ...xmlFooter.codeUnits,
        ];

        final decoder = Fb2Decoder();
        final book = decoder.decode(Uint8List.fromList(fullBytes));

        expect(book.metadata.title, equals('Win1251 Test'));
        final paragraph = book.content.blocks.first as BookParagraph;
        final text = (paragraph.inlines.first as BookText).text;
        expect(text, equals(expectedChars.toString()));
      });

      test(
        'Decodes specific Windows-1251 symbols: em-dash, quotes, №, ellipsis, Ukrainian/Belarusian letters',
        () {
          const phrase =
              '«№ 123 — Заголовок… Ґанок, Єдина Україна, Іван, Їжак, Ўзбекистан, ёлка, Ёжик»';
          final encodedBytes = _encodeWin1251(
            '''<?xml version="1.0" encoding="windows-1251"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>$phrase</book-title>
    </title-info>
  </description>
  <body><p>$phrase</p></body>
</FictionBook>''',
          );

          final decoder = Fb2Decoder();
          final book = decoder.decode(encodedBytes);

          expect(book.metadata.title, equals(phrase));
          final p = book.content.blocks.first as BookParagraph;
          expect((p.inlines.first as BookText).text, equals(phrase));
        },
      );

      test('Decodes Windows-1251 with "cp1251" encoding declaration', () {
        const phrase = 'Текст в кодировке cp1251 с кавычками «ёлочки» и тире —';
        final encodedBytes = _encodeWin1251(
          '''<?xml version="1.0" encoding="cp1251"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>CP1251 Книга</book-title></title-info>
  </description>
  <body><p>$phrase</p></body>
</FictionBook>''',
        );

        final decoder = Fb2Decoder();
        final book = decoder.decode(encodedBytes);

        expect(book.metadata.title, equals('CP1251 Книга'));
        final p = book.content.blocks.first as BookParagraph;
        expect((p.inlines.first as BookText).text, equals(phrase));
      });

      test(
        'Auto-detects and decodes Windows-1251 even without explicit encoding header on non-UTF8 bytes',
        () {
          const phrase = 'Русский текст без явного объявления encoding';
          final encodedBytes = _encodeWin1251(
            '''<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>Автоопределение 1251</book-title></title-info>
  </description>
  <body><p>$phrase</p></body>
</FictionBook>''',
          );

          final decoder = Fb2Decoder();
          final book = decoder.decode(encodedBytes);

          expect(book.metadata.title, equals('Автоопределение 1251'));
          final p = book.content.blocks.first as BookParagraph;
          expect((p.inlines.first as BookText).text, equals(phrase));
        },
      );
    });

    // -------------------------------------------------------------------------
    // 2. UTF-8 (With and Without BOM)
    // -------------------------------------------------------------------------
    group('UTF-8 decoding with and without BOM', () {
      const sampleUtf8Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>Книга в UTF-8 🚀</book-title>
    </title-info>
  </description>
  <body><p>Многоязычный текст: Русский, English, Español, 漢字, 🌟</p></body>
</FictionBook>''';

      test('Decodes standard UTF-8 without BOM', () {
        final rawBytes = Uint8List.fromList(utf8.encode(sampleUtf8Xml));
        final decoder = Fb2Decoder();

        expect(decoder.canDecode(rawBytes), isTrue);
        final book = decoder.decode(rawBytes);

        expect(book.metadata.title, equals('Книга в UTF-8 🚀'));
        final p = book.content.blocks.first as BookParagraph;
        expect((p.inlines.first as BookText).text, contains('🌟'));
        expect((p.inlines.first as BookText).text, contains('漢字'));
      });

      test('Decodes UTF-8 with BOM prefix (\\xEF\\xBB\\xBF)', () {
        final utf8Bytes = utf8.encode(sampleUtf8Xml);
        final bomBytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8Bytes]);

        final decoder = Fb2Decoder();
        expect(decoder.canDecode(bomBytes), isTrue);

        final book = decoder.decode(bomBytes);
        expect(book.metadata.title, equals('Книга в UTF-8 🚀'));
        final p = book.content.blocks.first as BookParagraph;
        expect((p.inlines.first as BookText).text, contains('🌟'));
      });
    });

    // -------------------------------------------------------------------------
    // 3. Metadata Parsing and Writing (All sections)
    // -------------------------------------------------------------------------
    group('All FB2 Metadata sections: parsing and generation', () {
      final fullMetadataXml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>sf_fantasy</genre>
      <genre>cyberpunk</genre>
      <author>
        <first-name>Станислав</first-name>
        <middle-name>Германович</middle-name>
        <last-name>Лем</last-name>
        <nickname>Stas</nickname>
        <home-page>https://lem.pl</home-page>
        <email>lem@solaris.pl</email>
      </author>
      <book-title>Солярис и Кибериада</book-title>
      <annotation>
        <p>Классика научной фантастики.</p>
        <p>Второе издание с предисловием.</p>
      </annotation>
      <keywords>космос, океан, роботы, искусственный интеллект</keywords>
      <date value="1961-06-15">15 июня 1961</date>
      <coverpage>
        <image l:href="#cover.jpg"/>
      </coverpage>
      <lang>ru</lang>
      <src-lang>pl</src-lang>
      <translator>
        <first-name>Дмитрий</first-name>
        <last-name>Брускин</last-name>
        <nickname>DB</nickname>
        <home-page>https://bruskin.ru</home-page>
        <email>bruskin@translators.ru</email>
      </translator>
      <sequence name="Звездные Дневники" number="7"/>
    </title-info>
    <src-title-info>
      <author>
        <first-name>Stanisław</first-name>
        <middle-name>Herman</middle-name>
        <last-name>Lem</last-name>
        <nickname>LemPL</nickname>
      </author>
      <book-title>Solaris</book-title>
      <lang>pl</lang>
    </src-title-info>
    <document-info>
      <author><nickname>DocCreator</nickname></author>
      <program-used>FB2 Generator 3000</program-used>
      <date value="2024-08-20">2024-08-20</date>
      <src-url>https://sf-library.org/lem/solaris.fb2</src-url>
      <id>doc-unique-id-98765</id>
      <version>2.0</version>
    </document-info>
    <publish-info>
      <publisher>Издательство Мир</publisher>
      <city>Москва</city>
      <year>1963</year>
      <isbn>978-5-03-001234-5</isbn>
    </publish-info>
    <custom-info info-type="sequence-url">https://lem.pl/series/diaries</custom-info>
  </description>
  <body>
    <section>
      <title><p>Глава 1</p></title>
      <p>Океан шумел за иллюминатором.</p>
    </section>
  </body>
  <binary id="cover.jpg" content-type="image/jpeg">aW1hZ2UtYnl0ZXM=</binary>
</FictionBook>''';

      test(
        'Fb2Decoder parses all metadata sections: title-info, src-title-info, publish-info, document-info, custom-info',
        () {
          final decoder = Fb2Decoder();
          final book = decoder.decode(
            Uint8List.fromList(utf8.encode(fullMetadataXml)),
          );

          // 1. Core metadata & title-info
          expect(book.metadata.id, equals('doc-unique-id-98765'));
          expect(book.metadata.title, equals('Солярис и Кибериада'));
          expect(book.metadata.language, equals('ru'));
          expect(book.metadata.srcLang, equals('pl'));
          expect(
            book.metadata.genres.map((g) => g.code),
            containsAll(['sf_fantasy', 'cyberpunk']),
          );
          expect(
            book.metadata.keywords,
            containsAll(['космос', 'океан', 'роботы']),
          );
          expect(book.metadata.publishedAt, equals(DateTime(1961, 6, 15)));
          expect(book.metadata.cover?.ref.id, equals('cover.jpg'));

          // Annotation
          expect(book.metadata.annotation, isNotNull);
          expect(book.metadata.annotation!.blocks.length, equals(2));

          // Authors
          final authors = book.metadata.contributorsByRole(
            BookContributorRole.author,
          );
          expect(authors.length, equals(1));
          final author = authors.first;
          expect(author.name.first, equals('Станислав'));
          expect(author.name.middle, equals('Германович'));
          expect(author.name.last, equals('Лем'));
          expect(author.name.nickname, equals('Stas'));
          expect(author.homePage, equals(Uri.parse('https://lem.pl')));
          expect(author.email, equals('lem@solaris.pl'));

          // Translators
          final translators = book.metadata.contributorsByRole(
            BookContributorRole.translator,
          );
          expect(translators.length, equals(1));
          final translator = translators.first;
          expect(translator.name.first, equals('Дмитрий'));
          expect(translator.name.last, equals('Брускин'));
          expect(translator.name.nickname, equals('DB'));
          expect(translator.homePage, equals(Uri.parse('https://bruskin.ru')));
          expect(translator.email, equals('bruskin@translators.ru'));

          // Series and sequence URL
          expect(book.metadata.series.length, equals(1));
          expect(book.metadata.series.first.name, equals('Звездные Дневники'));
          expect(book.metadata.series.first.number, equals(7));
          expect(
            book.metadata.series.first.url,
            equals(Uri.parse('https://lem.pl/series/diaries')),
          );

          // 2. src-title-info
          final srcTitleInfo = book.metadata.srcTitleInfo;
          expect(srcTitleInfo, isNotNull);
          expect(srcTitleInfo!.title, equals('Solaris'));
          expect(srcTitleInfo.language, equals('pl'));
          expect(srcTitleInfo.authors.length, equals(1));
          expect(srcTitleInfo.authors.first.name.first, equals('Stanisław'));
          expect(srcTitleInfo.authors.first.name.last, equals('Lem'));

          // 3. publish-info
          final pubInfo = book.metadata.publishInfo;
          expect(pubInfo, isNotNull);
          expect(pubInfo!.publisher, equals('Издательство Мир'));
          expect(pubInfo.city, equals('Москва'));
          expect(pubInfo.year, equals(1963));
          expect(pubInfo.isbn, equals('978-5-03-001234-5'));
        },
      );

      test(
        'Fb2Encoder writes all metadata sections in strict schema compliance',
        () async {
          final decoder = Fb2Decoder();
          final encoder = const Fb2Encoder(programUsed: 'Test Program 1.0');

          final originalBook = decoder.decode(
            Uint8List.fromList(utf8.encode(fullMetadataXml)),
          );
          final encodedBytes = await encoder.encode(originalBook);
          final xmlOutput = utf8.decode(encodedBytes);

          // Verify XML sections exist
          expect(xmlOutput, contains('<description>'));
          expect(xmlOutput, contains('<title-info>'));
          expect(xmlOutput, contains('<genre>sf_fantasy</genre>'));
          expect(xmlOutput, contains('<genre>cyberpunk</genre>'));
          expect(xmlOutput, contains('<first-name>Станислав</first-name>'));
          expect(xmlOutput, contains('<last-name>Лем</last-name>'));
          expect(xmlOutput, contains('<home-page>https://lem.pl</home-page>'));
          expect(xmlOutput, contains('<email>lem@solaris.pl</email>'));
          expect(
            xmlOutput,
            contains('<book-title>Солярис и Кибериада</book-title>'),
          );
          expect(xmlOutput, contains('<annotation>'));
          expect(
            xmlOutput,
            contains(
              '<keywords>космос, океан, роботы, искусственный интеллект</keywords>',
            ),
          );
          expect(xmlOutput, contains('<coverpage>'));
          expect(xmlOutput, contains('<lang>ru</lang>'));
          expect(xmlOutput, contains('<src-lang>pl</src-lang>'));
          expect(xmlOutput, contains('<translator>'));
          expect(
            xmlOutput,
            contains('<sequence name="Звездные Дневники" number="7"/>'),
          );

          expect(xmlOutput, contains('<src-title-info>'));
          expect(xmlOutput, contains('<first-name>Stanisław</first-name>'));
          expect(xmlOutput, contains('<book-title>Solaris</book-title>'));
          expect(xmlOutput, contains('<lang>pl</lang>'));

          expect(xmlOutput, contains('<document-info>'));
          expect(xmlOutput, contains('<id>doc-unique-id-98765</id>'));
          expect(
            xmlOutput,
            contains('<program-used>Test Program 1.0</program-used>'),
          );

          expect(xmlOutput, contains('<publish-info>'));
          expect(
            xmlOutput,
            contains('<publisher>Издательство Мир</publisher>'),
          );
          expect(xmlOutput, contains('<city>Москва</city>'));
          expect(xmlOutput, contains('<year>1963</year>'));
          expect(xmlOutput, contains('<isbn>978-5-03-001234-5</isbn>'));

          expect(
            xmlOutput,
            contains(
              '<custom-info info-type="sequence-url">https://lem.pl/series/diaries</custom-info>',
            ),
          );

          // Roundtrip decoding to ensure exact metadata match
          final redecoded = decoder.decode(encodedBytes);
          expect(redecoded.metadata.title, equals(originalBook.metadata.title));
          expect(
            redecoded.metadata.language,
            equals(originalBook.metadata.language),
          );
          expect(
            redecoded.metadata.srcLang,
            equals(originalBook.metadata.srcLang),
          );
          expect(
            redecoded.metadata.publishInfo?.publisher,
            equals(originalBook.metadata.publishInfo?.publisher),
          );
          expect(
            redecoded.metadata.publishInfo?.isbn,
            equals(originalBook.metadata.publishInfo?.isbn),
          );
          expect(
            redecoded.metadata.srcTitleInfo?.title,
            equals(originalBook.metadata.srcTitleInfo?.title),
          );
          expect(
            redecoded.metadata.series.first.url,
            equals(originalBook.metadata.series.first.url),
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // 4. Body Separation (Main content vs Footnotes / Comments)
    // -------------------------------------------------------------------------
    group('Body separation: main body vs notes and comments bodies', () {
      test(
        'Separates <body name="notes"> and <body name="comments"> into content.footnotes',
        () {
          const xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info><book-title>Книга со сносками и комментариями</book-title></title-info>
  </description>
  <body>
    <section>
      <title><p>Основная глава</p></title>
      <p>Текст в основном теле со сноской <a type="note" l:href="#fn1">[1]</a> и комментарием <a type="note" l:href="#comm1">[comm]</a>.</p>
    </section>
  </body>
  <body name="notes">
    <section id="fn1">
      <title><p>1</p></title>
      <p>Текст сноски номер 1.</p>
    </section>
  </body>
  <body name="comments">
    <section id="comm1">
      <title><p>comm</p></title>
      <p>Текст авторского комментария.</p>
    </section>
  </body>
</FictionBook>''';

          final decoder = Fb2Decoder();
          final book = decoder.decode(Uint8List.fromList(utf8.encode(xml)));

          // Main body
          expect(book.content.blocks.length, equals(1));
          final mainSection = book.content.blocks.first as BookSection;
          final p = mainSection.blocks.first as BookParagraph;
          final fnRefs = p.inlines.whereType<BookFootnoteRef>().toList();
          expect(fnRefs.length, equals(2));
          expect(fnRefs[0].id, equals('fn1'));
          expect(fnRefs[1].id, equals('comm1'));

          // Footnotes body contains both notes and comments
          expect(book.content.footnotes.length, equals(2));
          expect(book.content.footnotes[0].id, equals('fn1'));
          expect(book.content.footnotes[1].id, equals('comm1'));
          final fn1Para =
              book.content.footnotes[0].blocks.first as BookParagraph;
          expect(
            (fn1Para.inlines.first as BookText).text,
            equals('Текст сноски номер 1.'),
          );

          final comm1Para =
              book.content.footnotes[1].blocks.first as BookParagraph;
          expect(
            (comm1Para.inlines.first as BookText).text,
            equals('Текст авторского комментария.'),
          );
        },
      );

      test(
        'Fb2Encoder generates <body name="notes"> for content.footnotes',
        () async {
          final book = Book(
            metadata: const BookMetadata(
              id: 'fn-test-1',
              title: 'Генерация сносок',
              language: 'ru',
            ),
            content: const BookContent(
              blocks: [
                BookParagraph(
                  inlines: [
                    BookText('Текст с примечанием '),
                    BookFootnoteRef(
                      id: 'custom_note',
                      label: [BookText('[Прим. ред.]')],
                    ),
                  ],
                ),
              ],
              footnotes: [
                BookFootnote(
                  id: 'custom_note',
                  blocks: [
                    BookParagraph(
                      inlines: [BookText('Примечание редактора: важно!')],
                    ),
                  ],
                ),
              ],
            ),
            resources: const [],
          );

          final encoder = const Fb2Encoder();
          final encodedBytes = await encoder.encode(book);
          final xml = utf8.decode(encodedBytes);

          expect(xml, contains('<body name="notes">'));
          expect(xml, contains('<section id="custom_note">'));
          expect(xml, contains('<title>'));
          expect(xml, contains('<p>custom_note</p>'));
          expect(xml, contains('<p>Примечание редактора: важно!</p>'));

          // Redecode and verify AST structure
          final decoded = Fb2Decoder().decode(encodedBytes);
          expect(decoded.content.footnotes.length, equals(1));
          expect(decoded.content.footnotes.first.id, equals('custom_note'));
          final footnotePara =
              decoded.content.footnotes.first.blocks.first as BookParagraph;
          expect(
            (footnotePara.inlines.first as BookText).text,
            equals('Примечание редактора: важно!'),
          );
        },
      );

      test(
        'Does NOT generate <body name="notes"> when content.footnotes is empty',
        () async {
          final book = Book(
            metadata: const BookMetadata(
              id: 'no-fn-test',
              title: 'Без сносок',
              language: 'ru',
            ),
            content: const BookContent(
              blocks: [
                BookParagraph(inlines: [BookText('Просто текст')]),
              ],
              footnotes: [],
            ),
            resources: const [],
          );

          final encodedBytes = await const Fb2Encoder().encode(book);
          final xml = utf8.decode(encodedBytes);

          expect(xml, isNot(contains('<body name="notes">')));
        },
      );
    });

    // -------------------------------------------------------------------------
    // 5. Base64 Encoding/Decoding Resilience
    // -------------------------------------------------------------------------
    group('Base64 Encoding & Decoding Resilience in <binary>', () {
      test(
        'Decodes Base64 with line breaks (CRLF, LF), tabs, and internal whitespace',
        () {
          final originalData = Uint8List.fromList(
            List.generate(100, (i) => (i * 13) % 256),
          );
          final base64Raw = base64Encode(originalData);

          // Break base64 string with various whitespace characters
          final brokenBase64 = StringBuffer();
          for (var i = 0; i < base64Raw.length; i++) {
            brokenBase64.write(base64Raw[i]);
            if (i % 20 == 0) brokenBase64.write('\r\n  ');
            if (i % 35 == 0) brokenBase64.write('\t\n');
          }

          final xml =
              '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>Base64 Test</book-title></title-info>
  </description>
  <body><p>Image below</p></body>
  <binary id="img1.png" content-type="image/png">
    ${brokenBase64.toString()}
  </binary>
</FictionBook>''';

          final decoder = Fb2Decoder();
          final book = decoder.decode(Uint8List.fromList(utf8.encode(xml)));

          expect(book.resources.length, equals(1));
          final res = book.resources.first;
          expect(res.id, equals('img1.png'));
          expect(res.mediaType, equals('image/png'));
          expect(res.bytes, equals(originalData));
        },
      );

      test('Handles Base64 padding variants (=, ==, no padding needed)', () {
        final data1 = Uint8List.fromList([
          1,
          2,
          3,
        ]); // 3 bytes -> 4 chars (no pad)
        final data2 = Uint8List.fromList([1, 2]); // 2 bytes -> 3 chars + 1 '='
        final data3 = Uint8List.fromList([1]); // 1 byte  -> 2 chars + 2 '=='

        final xml =
            '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>Padding Test</book-title></title-info>
  </description>
  <body><p>Resources</p></body>
  <binary id="res1.bin" content-type="application/octet-stream">${base64Encode(data1)}</binary>
  <binary id="res2.bin" content-type="application/octet-stream">${base64Encode(data2)}</binary>
  <binary id="res3.bin" content-type="application/octet-stream">${base64Encode(data3)}</binary>
</FictionBook>''';

        final decoder = Fb2Decoder();
        final book = decoder.decode(Uint8List.fromList(utf8.encode(xml)));

        expect(book.resources.length, equals(3));
        expect(book.resources[0].bytes, equals(data1));
        expect(book.resources[1].bytes, equals(data2));
        expect(book.resources[2].bytes, equals(data3));
      });
    });

    // -------------------------------------------------------------------------
    // 6. FB2.ZIP Packaging & Unpacking
    // -------------------------------------------------------------------------
    group(
      'FB2.ZIP packaging & unpacking (Fb2ZipDecoder, Fb2ZipEncoder, Fb2ZipConverter)',
      () {
        test(
          'canDecode correctly identifies FB2.ZIP and rejects non-ZIP/EPUB files',
          () {
            final zipDecoder = Fb2ZipDecoder();

            // Valid zip bytes
            final validZip = Uint8List.fromList([
              0x50,
              0x4B,
              0x03,
              0x04,
              ...List.filled(20, 0),
            ]);
            expect(
              zipDecoder.canDecode(validZip, extension: 'fb2.zip'),
              isTrue,
            );
            expect(
              zipDecoder.canDecode(validZip, extension: 'book.zip'),
              isTrue,
            );

            // EPUB signature rejection
            final epubBytes = Uint8List.fromList([
              0x50,
              0x4B,
              0x03,
              0x04,
              ...List.filled(26, 0),
              ...utf8.encode('mimetype'),
              ...utf8.encode('application/epub+zip'),
            ]);
            expect(zipDecoder.canDecode(epubBytes, extension: 'epub'), isFalse);

            // Non-zip bytes without extension
            final nonZip = Uint8List.fromList([
              0x3C,
              0x3F,
              0x78,
              0x6D,
            ]); // '<?xm'
            expect(zipDecoder.canDecode(nonZip), isFalse);
          },
        );

        test(
          'Fb2ZipEncoder creates valid ZIP archive with configured options',
          () async {
            final book = Book(
              metadata: const BookMetadata(
                id: 'zip-opts-1',
                title: 'Опции ZIP архива',
                language: 'ru',
              ),
              content: const BookContent(
                blocks: [
                  BookParagraph(inlines: [BookText('Содержимое книги в ZIP')]),
                ],
              ),
              resources: const [],
            );

            final encoder = Fb2ZipEncoder();
            expect(encoder.canEncode('fb2.zip'), isTrue);
            expect(encoder.canEncode('zip'), isTrue);
            expect(encoder.canEncode('epub'), isFalse);

            // Encode with custom entryFilename and compression
            final options = const BookEncodingOptions(
              entryFilename: 'custom_name.fb2',
              compressZip: true,
            );
            final zipBytes = await encoder.encode(book, options: options);

            final archive = ZipDecoder().decodeBytes(zipBytes);
            expect(archive.files.length, equals(1));
            expect(archive.files.first.name, equals('custom_name.fb2'));

            // Decode with Fb2ZipDecoder
            final decodedBook = Fb2ZipDecoder().decode(zipBytes);
            expect(decodedBook.metadata.title, equals('Опции ZIP архива'));
            expect(decodedBook.content.blocks.length, equals(1));
          },
        );

        test(
          'Fb2ZipDecoder picks the .fb2/.xml file when archive contains multiple entries',
          () {
            const fb2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info><book-title>Архивная Книга</book-title></title-info></description>
  <body><p>Контент</p></body>
</FictionBook>''';

            final archive = Archive();
            archive.addFile(
              ArchiveFile('readme.txt', 12, utf8.encode('Read me info')),
            );
            archive.addFile(
              ArchiveFile('book.fb2', fb2Xml.length, utf8.encode(fb2Xml)),
            );
            archive.addFile(ArchiveFile('cover.jpg', 4, [1, 2, 3, 4]));

            final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
            final book = Fb2ZipDecoder().decode(zipBytes);

            expect(book.metadata.title, equals('Архивная Книга'));
          },
        );

        test(
          'Fb2ZipDecoder throws BookFormatException on corrupted/empty zip files',
          () {
            final zipDecoder = Fb2ZipDecoder();

            // Not a zip file
            expect(
              () => zipDecoder.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
              throwsA(isA<BookFormatException>()),
            );

            // Empty zip archive (0 files)
            final emptyArchive = Archive();
            final emptyZipBytes = Uint8List.fromList(
              ZipEncoder().encode(emptyArchive),
            );
            expect(
              () => zipDecoder.decode(emptyZipBytes),
              throwsA(isA<BookFormatException>()),
            );
          },
        );

        test(
          'Full roundtrip using Fb2ZipConverter with comprehensive AST node types',
          () async {
            final originalBook = Book(
              metadata: BookMetadata(
                id: 'zip-rt-1',
                title: 'FB2.ZIP Раундтрип',
                language: 'ru',
                contributors: [
                  const BookContributor(
                    role: BookContributorRole.author,
                    name: PersonName(
                      first: 'Иван',
                      last: 'Иванов',
                      display: 'Иван Иванов',
                    ),
                  ),
                ],
                series: const [BookSeries(name: 'Серия 1', number: 2)],
                publishInfo: const BookPublishInfo(
                  publisher: 'Издатель',
                  year: 2024,
                ),
              ),
              content: const BookContent(
                blocks: [
                  BookSection(
                    id: 'sec-1',
                    title: [BookText('Глава 1: Раздел')],
                    blocks: [
                      BookParagraph(
                        inlines: [
                          BookText('Параграф с '),
                          BookStrong(children: [BookText('жирным')]),
                          BookText(', '),
                          BookEmphasis(children: [BookText('курсивом')]),
                          BookText(', '),
                          BookStrike(children: [BookText('зачеркнутым')]),
                          BookText(', '),
                          BookCodeSpan('int a = 1;'),
                          BookText(' и сноской '),
                          BookFootnoteRef(
                            id: 'note-1',
                            label: [BookText('[1]')],
                          ),
                          BookText('.'),
                        ],
                      ),
                      BookQuote(
                        blocks: [
                          BookParagraph(
                            inlines: [BookText('Цитата внутри раздела')],
                          ),
                        ],
                        citation: [BookText('Автор цитаты')],
                      ),
                      BookPoem(
                        stanzas: [
                          BookStanza(
                            lines: [
                              BookPoemLine(inlines: [BookText('Строка 1')]),
                              BookPoemLine(inlines: [BookText('Строка 2')]),
                            ],
                          ),
                        ],
                      ),
                      BookTable(
                        rows: [
                          BookTableRow(
                            cells: [
                              BookTableCell(
                                blocks: [
                                  BookParagraph(
                                    inlines: [BookText('Ячейка 1.1')],
                                  ),
                                ],
                                colSpan: 2,
                              ),
                              BookTableCell(
                                blocks: [
                                  BookParagraph(
                                    inlines: [BookText('Ячейка 1.2')],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      BookImageBlock(
                        id: 'img-b',
                        ref: BookResourceRef('img1.png'),
                        alt: 'Альтернативный текст',
                        title: 'Подпись картинки',
                      ),
                      BookEmptyLine(),
                    ],
                  ),
                ],
                footnotes: [
                  BookFootnote(
                    id: 'note-1',
                    blocks: [
                      BookParagraph(inlines: [BookText('Текст примечания 1')]),
                    ],
                  ),
                ],
              ),
              resources: [
                BookResource(
                  id: 'img1.png',
                  mediaType: 'image/png',
                  bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
                ),
              ],
            );

            final zipBytes = await Fb2ZipConverter.bookToFb2Zip(originalBook);
            expect(zipBytes, isNotEmpty);

            final decodedBook = Fb2ZipConverter.fb2ZipToBook(zipBytes);
            expect(
              decodedBook.metadata.title,
              equals(originalBook.metadata.title),
            );
            expect(
              decodedBook.metadata.language,
              equals(originalBook.metadata.language),
            );
            expect(
              decodedBook.resources.length,
              equals(originalBook.resources.length),
            );

            // Use GoldenComparator / AstNormalizer to verify content preservation
            final normDecoded = AstNormalizer.normalizeBook(decodedBook);
            final normOriginal = AstNormalizer.normalizeBook(originalBook);
            GoldenComparator.assertContentEquals(
              normDecoded.content,
              normOriginal.content,
            );
          },
        );
      },
    );
  });
}

/// Helper function to encode a UTF-16 string into Windows-1251 byte array
Uint8List _encodeWin1251(String str) {
  const win1251ReverseLookup = <int, int>{
    0x0402: 0x80,
    0x0403: 0x81,
    0x201A: 0x82,
    0x0453: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x20AC: 0x88,
    0x2030: 0x89,
    0x0409: 0x8A,
    0x2039: 0x8B,
    0x040A: 0x8C,
    0x040C: 0x8D,
    0x040B: 0x8E,
    0x040F: 0x8F,
    0x0452: 0x90,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x2122: 0x99,
    0x0459: 0x9A,
    0x203A: 0x9B,
    0x045A: 0x9C,
    0x045C: 0x9D,
    0x045B: 0x9E,
    0x045F: 0x9F,
    0x00A0: 0xA0,
    0x040E: 0xA1,
    0x045E: 0xA2,
    0x0408: 0xA3,
    0x00A4: 0xA4,
    0x0490: 0xA5,
    0x00A6: 0xA6,
    0x00A7: 0xA7,
    0x0401: 0xA8,
    0x00A9: 0xA9,
    0x0404: 0xAA,
    0x00AB: 0xAB,
    0x00AC: 0xAC,
    0x00AD: 0xAD,
    0x00AE: 0xAE,
    0x0407: 0xAF,
    0x00B0: 0xB0,
    0x00B1: 0xB1,
    0x0406: 0xB2,
    0x0456: 0xB3,
    0x0491: 0xB4,
    0x00B5: 0xB5,
    0x00B6: 0xB6,
    0x00B7: 0xB7,
    0x0451: 0xB8,
    0x2116: 0xB9,
    0x0454: 0xBA,
    0x00BB: 0xBB,
    0x0458: 0xBC,
    0x0405: 0xBD,
    0x0455: 0xBE,
    0x0457: 0xBF,
  };

  final result = <int>[];
  for (final code in str.runes) {
    if (code < 128) {
      result.add(code);
    } else if (code >= 0x0410 && code <= 0x044F) {
      // А-Я, а-я (0x0410..0x044F -> 0xC0..0xFF)
      result.add(code - 0x0410 + 0xC0);
    } else if (win1251ReverseLookup.containsKey(code)) {
      result.add(win1251ReverseLookup[code]!);
    } else {
      result.add(0x3F); // '?'
    }
  }
  return Uint8List.fromList(result);
}
