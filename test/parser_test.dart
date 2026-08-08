import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlParser Tests', () {
    final parser = HtmlParser();

    test('Parses headings and paragraphs', () {
      const html = '<h1>Title</h1><p>Paragraph text <strong>bold</strong></p>';
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(2));
      expect(blocks[0], isA<BookHeading>());
      final heading = blocks[0] as BookHeading;
      expect(heading.level, equals(1));
      expect((heading.text.first as BookText).text, equals('Title'));

      expect(blocks[1], isA<BookParagraph>());
      final paragraph = blocks[1] as BookParagraph;
      expect(paragraph.inlines.length, equals(2));
      expect((paragraph.inlines[0] as BookText).text, equals('Paragraph text '));
      expect(paragraph.inlines[1], isA<BookStrong>());
    });

    test('Parses lists and tables', () {
      const html = '''
        <ul><li>Item 1</li><li>Item 2</li></ul>
        <table><tr><td>Cell 1</td><td>Cell 2</td></tr></table>
      ''';
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(2));
      expect(blocks[0], isA<BookList>());
      final list = blocks[0] as BookList;
      expect(list.ordered, isFalse);
      expect(list.items.length, equals(2));

      expect(blocks[1], isA<BookTable>());
      final table = blocks[1] as BookTable;
      expect(table.rows.length, equals(1));
      expect(table.rows[0].cells.length, equals(2));
    });

    test('Parses code blocks and blockquotes', () {
      const html = '''
        <blockquote><p>Quote text</p></blockquote>
        <pre><code class="language-dart">void main() {}</code></pre>
      ''';
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(2));
      expect(blocks[0], isA<BookQuote>());
      expect(blocks[1], isA<BookCodeBlock>());
      final codeBlock = blocks[1] as BookCodeBlock;
      expect(codeBlock.code, contains('void main()'));
    });
  });

  group('Fb2Parser Tests', () {
    final parser = Fb2Parser();

    test('Parses FB2 body structure and sections', () {
      const xml = '''
        <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
          <body>
            <section id="sec1">
              <title><p>Chapter 1</p></title>
              <p>Hello <strong>World</strong></p>
            </section>
          </body>
        </FictionBook>
      ''';
      final blocks = parser.parseFromString(xml);

      expect(blocks.length, equals(1));
      expect(blocks[0], isA<BookSection>());
      final section = blocks[0] as BookSection;
      expect(section.id, equals('sec1'));
      expect(section.blocks.length, equals(1));
      expect(section.blocks[0], isA<BookParagraph>());
    });

    test('Parses FB2 inline elements correctly including emphasis', () {
      const xml = '''
        <p>Text with <emphasis>emphasis</emphasis> and <strong>strong</strong></p>
      ''';
      final blocks = parser.parseFromString(xml);

      expect(blocks.length, equals(1));
      expect(blocks[0], isA<BookParagraph>());
      final p = blocks[0] as BookParagraph;
      expect(p.inlines.any((i) => i is BookEmphasis), isTrue);
      expect(p.inlines.any((i) => i is BookStrong), isTrue);
    });
  });
}
