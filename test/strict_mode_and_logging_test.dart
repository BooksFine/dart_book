import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Zero Fallbacks & Strict Mode Tests', () {
    test('HtmlParser throws BookParseException in strictMode on unhandled elements', () {
      final parser = HtmlParser(strictMode: true);
      expect(
        () => parser.parseFromString('<unknown-tag>content</unknown-tag>'),
        throwsA(isA<BookParseException>()),
      );
    });

    test('HtmlParser logs explicit warning when logger is provided', () {
      final warnings = <String>[];
      final parser = HtmlParser(
        strictMode: false,
        logger: (w) => warnings.add(w),
      );

      final blocks = parser.parseFromString('<custom-widget>Text</custom-widget>');
      expect(blocks.length, equals(1));
      expect(blocks.first, isA<BookRawHtmlBlock>());
      expect(warnings.length, equals(1));
      expect(warnings.first, contains('unhandled HTML element <custom-widget>'));
    });

    test('Fb2Parser throws BookParseException in strictMode on unhandled elements', () {
      final parser = Fb2Parser(strictMode: true);
      expect(
        () => parser.parseFromString('<body name="main"><unsupported-elem>Text</unsupported-elem></body>'),
        throwsA(isA<BookParseException>()),
      );
    });

    test('Fb2Decoder throws BookMalformedMetadataException in strictMode on missing title', () {
      final decoder = Fb2Decoder();
      const invalidFb2 = '''
<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <lang>ru</lang>
    </title-info>
  </description>
  <body><p>Text</p></body>
</FictionBook>
''';

      expect(
        () => decoder.decode(
          Uint8List.fromList(invalidFb2.codeUnits),
          options: const BookDecodingOptions(strictMode: true),
        ),
        throwsA(isA<BookMalformedMetadataException>()),
      );
    });

    test('Fb2Decoder logs warning when book-title is missing in non-strict mode', () {
      final warnings = <String>[];
      final decoder = Fb2Decoder();
      const invalidFb2 = '''
<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <lang>ru</lang>
    </title-info>
  </description>
  <body><p>Text</p></body>
</FictionBook>
''';

      final book = decoder.decode(
        Uint8List.fromList(invalidFb2.codeUnits),
        options: BookDecodingOptions(
          strictMode: false,
          logger: (w) => warnings.add(w),
        ),
      );

      expect(book.metadata.title, equals('Untitled'));
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('missing <book-title>'));
    });
  });
}
