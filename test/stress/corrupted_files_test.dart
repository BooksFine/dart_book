import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Stress: Corrupted XML & Error Recovery', () {
    test('FB2: Strips invalid XML 1.0 control characters (0x00-0x1F) in non-strict mode', () {
      final xmlWithControls = '<?xml version="1.0" encoding="UTF-8"?>'
          '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">'
          '<description><title-info><book-title>Control\x01Chars\x07Book\x1F</book-title></title-info></description>'
          '<body><p>Текст с\x02контрольными\x08символами\x0Bи\x0Cпереносами\x0E.</p></body>'
          '</FictionBook>';

      final bytes = Uint8List.fromList(utf8.encode(xmlWithControls));

      // 1. Non-strict mode: succeeds and strips control characters
      final book = Fb2Decoder().decode(bytes, options: const BookDecodingOptions(strictMode: false));
      expect(book.metadata.title, equals('ControlCharsBook'));
      final p = book.content.blocks.first as BookParagraph;
      final text = (p.inlines.first as BookText).text;
      expect(text, equals('Текст сконтрольнымисимволамиипереносами.'));

      // 2. Strict mode: throws BookParseException
      expect(
        () => Fb2Decoder().decode(bytes, options: const BookDecodingOptions(strictMode: true)),
        throwsA(isA<BookParseException>()),
      );
    });

    test('FB2: Recovers from unescaped ampersands (AT&T, Barnes & Noble, R&D) in non-strict mode', () {
      const xmlWithAmp = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>AT&T and Barnes & Noble History</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <p>Компании AT&T и Barnes & Noble сотрудничают в сфере R&D и M&A & инвестиций.</p>
  </body>
</FictionBook>''';

      final bytes = Uint8List.fromList(utf8.encode(xmlWithAmp));

      // Non-strict mode: parses and preserves text
      final book = Fb2Decoder().decode(bytes, options: const BookDecodingOptions(strictMode: false));
      expect(book.metadata.title, contains('AT&T'));
      final p = book.content.blocks.first as BookParagraph;
      final text = (p.inlines.first as BookText).text;
      expect(text, contains('AT&T'));
      expect(text, contains('Barnes & Noble'));
      expect(text, contains('R&D'));

      // Strict mode: throws BookParseException
      expect(
        () => Fb2Decoder().decode(bytes, options: const BookDecodingOptions(strictMode: true)),
        throwsA(isA<BookParseException>()),
      );
    });

    test('FB2: Sanitizes undeclared HTML entities (&nbsp;, &mdash;, &laquo;, &raquo;) in non-strict mode', () {
      const xmlWithEntities = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>&laquo;Война и мир&raquo; &mdash; Том 1</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <p>Текст с неразрывным&nbsp;пробелом, тире&mdash;и кавычками&laquo;в тексте&raquo;&hellip; а также &copy; и &euro;.</p>
  </body>
</FictionBook>''';

      final bytes = Uint8List.fromList(utf8.encode(xmlWithEntities));

      // Non-strict mode succeeds
      final book = Fb2Decoder().decode(bytes, options: const BookDecodingOptions(strictMode: false));
      expect(book.metadata.title, contains('«Война и мир»'));
      final p = book.content.blocks.first as BookParagraph;
      final text = (p.inlines.first as BookText).text;
      expect(text, contains('«в тексте»'));
      expect(text, contains('©'));

      // Strict mode throws BookParseException
      expect(
        () => Fb2Decoder().decode(bytes, options: const BookDecodingOptions(strictMode: true)),
        throwsA(isA<BookParseException>()),
      );
    });

    test('FB2: Resilient Base64 decoding in <binary> handles whitespace, newlines, and missing padding', () {
      // 1. Base64 of 'Hello World' = SGVsbG8gV29ybGQ= (with spaces/newlines/missing padding)
      const xmlBase64 = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info><book-title>Base64 Test</book-title></title-info></description>
  <body><p>Content</p></body>
  <binary id="img_spaces" content-type="image/png">
    SGVs bG8g
    V29y bGQ=
  </binary>
  <binary id="img_no_pad" content-type="image/jpeg">
    SGVsbG8gV29ybGQ
  </binary>
  <binary id="img_empty" content-type="image/png"></binary>
</FictionBook>''';

      final bytes = Uint8List.fromList(utf8.encode(xmlBase64));
      final book = Fb2Decoder().decode(bytes);

      expect(book.resources, hasLength(3));

      final resSpaces = book.resources.firstWhere((r) => r.id == 'img_spaces');
      expect(utf8.decode(resSpaces.bytes), equals('Hello World'));

      final resNoPad = book.resources.firstWhere((r) => r.id == 'img_no_pad');
      expect(utf8.decode(resNoPad.bytes), equals('Hello World'));

      final resEmpty = book.resources.firstWhere((r) => r.id == 'img_empty');
      expect(resEmpty.bytes, isEmpty);
    });

    test('FB2: Automatic encoding fallback when Windows-1251 bytes are paired with UTF-8 XML header', () {
      // Create XML with <?xml version="1.0" encoding="UTF-8"?> header, but actual bytes in Windows-1251
      final header = utf8.encode('<?xml version="1.0" encoding="UTF-8"?><FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"><description><title-info><book-title>');
      // CP1251 for "Привет мир": П (0xCF), р (0xF0), и (0xE8), в (0xE2), е (0xE5), т (0xF2), ' ' (0x20), м (0xEC), и (0xE8), р (0xF0)
      final cp1251Title = [0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2, 0x20, 0xEC, 0xE8, 0xF0];
      final body = utf8.encode('</book-title></title-info></description><body><p>Текст</p></body></FictionBook>');

      final rawBytes = Uint8List.fromList([...header, ...cp1251Title, ...body]);

      final book = Fb2Decoder().decode(rawBytes);
      expect(book.metadata.title, equals('Привет мир'));
    });
  });

  group('Stress: Strict Mode vs Lenient Fallback', () {
    test('HtmlParser: strictMode = true throws BookParseException with tag name; strictMode = false falls back', () {
      const htmlSrc = '<p>Good paragraph</p><unknown-widget data="val">Widget Text</unknown-widget>';

      // Strict mode
      final strictParser = HtmlParser(strictMode: true);
      expect(
        () => strictParser.parseFromString(htmlSrc),
        throwsA(
          isA<BookParseException>()
              .having((e) => e.tag, 'tag', 'unknown-widget')
              .having((e) => e.message, 'message', contains('Unhandled HTML element')),
        ),
      );

      // Non-strict mode
      final warnings = <String>[];
      final lenientParser = HtmlParser(
        strictMode: false,
        logger: (w) => warnings.add(w),
      );
      final blocks = lenientParser.parseFromString(htmlSrc);
      expect(blocks.length, equals(2));
      expect(blocks.first, isA<BookParagraph>());
      expect(blocks.last, isA<BookRawHtmlBlock>());
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('unknown-widget'));
    });

    test('HtmlParser: strictMode = true throws BookParseException on unhandled inline elements', () {
      const htmlSrc = '<p>Normal text <custom-inline>Custom</custom-inline> end</p>';

      final strictParser = HtmlParser(strictMode: true);
      expect(
        () => strictParser.parseFromString(htmlSrc),
        throwsA(
          isA<BookParseException>()
              .having((e) => e.tag, 'tag', 'custom-inline'),
        ),
      );

      final warnings = <String>[];
      final lenientParser = HtmlParser(
        strictMode: false,
        logger: (w) => warnings.add(w),
      );
      final blocks = lenientParser.parseFromString(htmlSrc);
      expect(blocks.length, equals(1));
      expect(warnings, isNotEmpty);
    });

    test('Fb2Parser: strictMode = true throws BookParseException on unhandled FB2 tags', () {
      const fb2Section = '<section><title><p>Title</p></title><custom-fb2-tag>Text</custom-fb2-tag></section>';

      final strictParser = Fb2Parser(strictMode: true);
      expect(
        () => strictParser.parseFromString(fb2Section),
        throwsA(
          isA<BookParseException>()
              .having((e) => e.tag, 'tag', 'custom-fb2-tag'),
        ),
      );

      final warnings = <String>[];
      final lenientParser = Fb2Parser(
        strictMode: false,
        logger: (w) => warnings.add(w),
      );
      final blocks = lenientParser.parseFromString(fb2Section);
      expect(blocks, isNotEmpty);
      expect(warnings, isNotEmpty);
    });

    test('Fb2Decoder & EpubDecoder: strictMode = true throws BookMalformedMetadataException on missing title', () async {
      // FB2 missing title
      const fb2NoTitle = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info><lang>ru</lang></title-info></description>
  <body><p>Text</p></body>
</FictionBook>''';
      final fb2Bytes = Uint8List.fromList(utf8.encode(fb2NoTitle));

      expect(
        () => Fb2Decoder().decode(fb2Bytes, options: const BookDecodingOptions(strictMode: true)),
        throwsA(isA<BookMalformedMetadataException>()),
      );

      // Non-strict mode falls back to 'Untitled'
      final fb2Book = Fb2Decoder().decode(fb2Bytes, options: const BookDecodingOptions(strictMode: false));
      expect(fb2Book.metadata.title, equals('Untitled'));
    });
  });
}
