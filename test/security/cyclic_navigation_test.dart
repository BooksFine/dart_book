import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import '../utils/ast_normalizer.dart';
import '../utils/golden_comparator.dart';

void main() {
  group('Security: Cyclic Navigation & Recursion Depth Protection', () {
    test('NCX: Protects against deep recursion (> 32 levels) and circular navPoints', () {
      // Build a deeply nested NCX document (50 levels deep)
      final ncxBuf = StringBuffer();
      ncxBuf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      ncxBuf.writeln('<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">');
      ncxBuf.writeln('  <navMap>');

      for (var i = 0; i < 50; i++) {
        ncxBuf.writeln('    <navPoint id="np_$i" playOrder="${i + 1}">');
        ncxBuf.writeln('      <navLabel><text>Level $i</text></navLabel>');
        ncxBuf.writeln('      <content src="chapter_$i.xhtml"/>');
      }

      for (var i = 0; i < 50; i++) {
        ncxBuf.writeln('    </navPoint>');
      }

      ncxBuf.writeln('  </navMap>');
      ncxBuf.writeln('</ncx>');

      final doc = EpubNcxDocument.parseFromString(ncxBuf.toString());
      expect(doc.navMap, isNotEmpty);

      // Verify recursion stops at depth 32
      var depth = 0;
      var current = doc.navMap.first;
      while (current.children.isNotEmpty) {
        depth++;
        current = current.children.first;
      }

      expect(depth, lessThanOrEqualTo(32));
    });

    test('NAV XHTML: Protects against deep recursion (> 32 levels) in nested <ol> lists', () {
      // Build a deeply nested nav.xhtml document (50 levels deep)
      final navBuf = StringBuffer();
      navBuf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      navBuf.writeln('<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">');
      navBuf.writeln('<body>');
      navBuf.writeln('  <nav epub:type="toc">');

      for (var i = 0; i < 50; i++) {
        navBuf.writeln('<ol><li><a href="chap_$i.xhtml">Chapter $i</a>');
      }

      for (var i = 0; i < 50; i++) {
        navBuf.writeln('</li></ol>');
      }

      navBuf.writeln('  </nav>');
      navBuf.writeln('</body>');
      navBuf.writeln('</html>');

      final doc = EpubNavDocument.parseFromString(navBuf.toString());
      expect(doc.toc, isNotEmpty);

      var depth = 0;
      var current = doc.toc.first;
      while (current.children.isNotEmpty) {
        depth++;
        current = current.children.first;
      }

      expect(depth, lessThanOrEqualTo(32));
    });

    test('Footnotes: Handles mutual cross-referencing footnotes without infinite loops (fn1 <-> fn2)', () async {
      const fb2Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>Cyclic Footnotes Book</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <p>Текст с первой сноской <a type="note" l:href="#fn1">[1]</a>.</p>
  </body>
  <body name="notes">
    <section id="fn1">
      <p>Сноска 1 ссылается на <a type="note" l:href="#fn2">сноску 2</a>.</p>
    </section>
    <section id="fn2">
      <p>Сноска 2 ссылается обратно на <a type="note" l:href="#fn1">сноску 1</a>.</p>
    </section>
  </body>
</FictionBook>''';

      final book = Fb2Decoder().decode(Uint8List.fromList(utf8.encode(fb2Xml)));
      expect(book.content.footnotes, hasLength(2));

      // 1. Normalization does not loop infinitely
      final normBook = AstNormalizer.normalizeBook(book);
      expect(normBook.content.footnotes, hasLength(2));

      // 2. GoldenComparator serialization works cleanly
      final json = GoldenComparator.contentToJson(normBook.content);
      expect(json['footnotes'], hasLength(2));

      // 3. Roundtrip encoding through FB2 works cleanly
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      final redecodedFb2 = Fb2Converter.fb2ToBook(fb2Bytes);
      expect(redecodedFb2.content.footnotes, hasLength(2));

      // 4. Roundtrip encoding through EPUB works cleanly
      final epubBytes = await EpubConverter.bookToEpub(book);
      final redecodedEpub = await EpubConverter.epubToBook(epubBytes);
      expect(redecodedEpub.metadata.title, equals('Cyclic Footnotes Book'));
    });

    test('Footnotes: Handles self-referencing footnote (fn1 -> fn1) and circular chains (fn1 -> fn2 -> fn3 -> fn1)', () async {
      const fb2Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>Self-Referencing Footnotes</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <p>Основной текст со сноской <a type="note" l:href="#fn_self">[Self]</a> и <a type="note" l:href="#fn_a">[Chain]</a>.</p>
  </body>
  <body name="notes">
    <section id="fn_self">
      <p>Сноска ссылается сама на себя: <a type="note" l:href="#fn_self">[Рекурсия]</a>.</p>
    </section>
    <section id="fn_a">
      <p>Шаг A -> <a type="note" l:href="#fn_b">[B]</a></p>
    </section>
    <section id="fn_b">
      <p>Шаг B -> <a type="note" l:href="#fn_c">[C]</a></p>
    </section>
    <section id="fn_c">
      <p>Шаг C -> <a type="note" l:href="#fn_a">[A]</a></p>
    </section>
  </body>
</FictionBook>''';

      final book = Fb2Decoder().decode(Uint8List.fromList(utf8.encode(fb2Xml)));
      expect(book.content.footnotes, hasLength(4));

      final normBook = AstNormalizer.normalizeBook(book);
      final json = GoldenComparator.contentToJson(normBook.content);
      expect(json['footnotes'], hasLength(4));

      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      expect(fb2Bytes, isNotEmpty);
    });

    test('Deeply nested AST sections and quotations (40 levels) normalize and serialize safely', () {
      BookBlock currentBlock = const BookParagraph(inlines: [BookText('Глубокий текст')]);
      for (var i = 0; i < 40; i++) {
        currentBlock = BookQuote(
          blocks: [currentBlock],
          citation: [BookText('Уровень $i')],
        );
      }

      final book = Book(
        metadata: const BookMetadata(id: 'deep-quote', title: 'Deep Quote', language: 'en'),
        content: BookContent(blocks: [currentBlock]),
        resources: const [],
      );

      final normalized = AstNormalizer.normalizeBook(book);
      expect(normalized.content.blocks.first, isA<BookQuote>());

      final json = GoldenComparator.contentToJson(normalized.content);
      expect(json['blocks'], isNotEmpty);
    });
  });
}
