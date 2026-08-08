import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('HTML5 & EPUB 3 Content Documents Compliance Tests', () {
    test('HtmlParser handles <figure> and <figcaption>', () {
      const html = '''
        <figure>
          <img src="chart.png" alt="Alt Text"/>
          <figcaption>График продаж 2026</figcaption>
        </figure>
      ''';
      final parser = HtmlParser();
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(1));
      expect(blocks.first, isA<BookImageBlock>());
      final img = blocks.first as BookImageBlock;
      expect(img.alt, equals('График продаж 2026'));
    });

    test('HtmlParser extracts language from nested <pre><code class="language-dart">', () {
      const html = '''
        <pre><code class="language-dart">void main() { print('Hi'); }</code></pre>
      ''';
      final parser = HtmlParser();
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(1));
      expect(blocks.first, isA<BookCodeBlock>());
      final code = blocks.first as BookCodeBlock;
      expect(code.language, equals('dart'));
      expect(code.code, contains("print('Hi');"));
    });

    test('HtmlParser parses anchors (<a id="...">) and EPUB 3 noterefs', () {
      const html = '''
        <p>
          <a id="chapter-1"></a>
          Текст со сноской <a href="#n1" epub:type="noteref">[1]</a>.
        </p>
      ''';
      final parser = HtmlParser();
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(1));
      final p = blocks.first as BookParagraph;
      expect(p.inlines.any((i) => i is BookAnchor), isTrue);
      expect(p.inlines.any((i) => i is BookFootnoteRef), isTrue);

      final anchor = p.inlines.firstWhere((i) => i is BookAnchor) as BookAnchor;
      expect(anchor.id, equals('chapter-1'));

      final fnRef = p.inlines.firstWhere((i) => i is BookFootnoteRef) as BookFootnoteRef;
      expect(fnRef.id, equals('n1'));
    });

    test('HtmlParser parses inline tags cite, q, kbd, samp, var, time without BookRawHtmlInline', () {
      const html = '''
        <p>
          Цитата <cite>Книга</cite>, ввод <kbd>Ctrl+C</kbd>, вывод <samp>OK</samp>, переменная <var>x</var>, дата <time datetime="2026-08-09">сегодня</time>.
        </p>
      ''';
      final parser = HtmlParser();
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(1));
      final p = blocks.first as BookParagraph;
      expect(p.inlines.any((i) => i is BookRawHtmlInline), isFalse);
      expect(p.inlines.any((i) => i is BookEmphasis), isTrue);
      expect(p.inlines.any((i) => i is BookCodeSpan), isTrue);
    });

    test('HtmlParser throws BookParseException in strictMode for unhandled inline elements', () {
      const html = '<p>Текст <unhandled-inline>ошибка</unhandled-inline></p>';
      final parser = HtmlParser(strictMode: true);

      expect(
        () => parser.parseFromString(html),
        throwsA(isA<BookParseException>()),
      );
    });
  });
}
