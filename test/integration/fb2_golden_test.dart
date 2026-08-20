import 'dart:convert';
import 'dart:io';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import '../utils/golden_comparator.dart';

void main() {
  group('FB2 Golden Master Integration Tests', () {
    test('Parses LitRes FB2 sample (Win-1251, verses, epigraphs, footnotes, publish-info)', () async {
      final file = File('test/fixtures/fb2/litres_sample.fb2');
      expect(file.existsSync(), isTrue, reason: 'litres_sample.fb2 fixture must exist');

      final rawBytes = file.readAsBytesSync();
      final book = await DartBook.load(rawBytes, filename: 'litres_sample.fb2');

      // 1. Verify Metadata
      expect(book.metadata.title, equals('Евгений Онегин и стихотворения'));
      expect(book.metadata.language, equals('ru'));
      expect(book.metadata.id, equals('litres-book-uuid-123456'));
      expect(book.metadata.genres.map((g) => g.code), containsAll(['prose_classic', 'poetry']));
      expect(book.metadata.annotation, isNotNull);
      expect(book.metadata.cover, isNotNull);
      expect(book.metadata.cover!.ref.id, equals('cover.jpg'));
      expect(book.metadata.series, isNotEmpty);
      expect(book.metadata.series.first.name, equals('Русская Классика'));
      expect(book.metadata.series.first.number, equals(1));

      // Author metadata
      expect(book.metadata.contributors, isNotEmpty);
      final author = book.metadata.contributors.first;
      expect(author.name.first, equals('Александр'));
      expect(author.name.middle, equals('Сергеевич'));
      expect(author.name.last, equals('Пушкин'));
      expect(author.name.toDisplayString(), equals('Александр Сергеевич Пушкин'));
      expect(author.email, equals('pushkin@litres.ru'));

      // Publish Info
      expect(book.metadata.publishInfo, isNotNull);
      expect(book.metadata.publishInfo!.publisher, equals('Издательство Литрес Эксмо'));
      expect(book.metadata.publishInfo!.city, equals('Москва'));
      expect(book.metadata.publishInfo!.year, equals(2023));
      expect(book.metadata.publishInfo!.isbn, equals('978-5-04-123456-7'));

      // 2. Verify Key AST Nodes
      final blocks = book.content.blocks;
      expect(blocks, isNotEmpty);

      // Epigraph at book root
      final rootEpigraph = blocks.firstWhere((b) => b is BookQuote && b.attributes['fb2-type'] == 'epigraph') as BookQuote;
      expect(rootEpigraph.citation.isNotEmpty, isTrue);
      expect((rootEpigraph.citation.first as BookText).text, contains('Вяземский'));

      // Main section
      final section = blocks.firstWhere((b) => b is BookSection) as BookSection;
      expect((section.title.first as BookText).text, equals('Глава I'));

      // Section epigraph
      final secEpigraph = section.blocks.firstWhere((b) => b is BookQuote && b.attributes['fb2-type'] == 'epigraph') as BookQuote;
      expect((secEpigraph.citation.first as BookText).text, contains('Грибоедов'));

      // Poem
      final poem = section.blocks.firstWhere((b) => b is BookPoem) as BookPoem;
      expect(poem.stanzas.length, equals(1));
      expect(poem.stanzas.first.lines.length, equals(4));
      expect((poem.stanzas.first.lines.first.inlines.first as BookText).text, contains('Так думал молодой повеса'));

      // Footnote references in paragraphs
      final paragraphs = section.blocks.whereType<BookParagraph>().toList();
      final hasFnRef1 = paragraphs.any((p) => p.inlines.any((i) => i is BookFootnoteRef && i.id == 'note_1'));
      final hasFnRef2 = paragraphs.any((p) => p.inlines.any((i) => i is BookFootnoteRef && i.id == 'note_2'));
      expect(hasFnRef1, isTrue);
      expect(hasFnRef2, isTrue);

      // Footnote content
      expect(book.content.footnotes.length, equals(2));
      expect(book.content.footnotes.any((fn) => fn.id == 'note_1'), isTrue);
      expect(book.content.footnotes.any((fn) => fn.id == 'note_2'), isTrue);

      // 3. Golden JSON serialization
      final goldenJson = GoldenComparator.contentToJson(book.content);
      expect(goldenJson['blocks'], isNotEmpty);
      expect(goldenJson['footnotes'], hasLength(2));

      final jsonStr = jsonEncode(goldenJson);
      expect(jsonStr, contains('poem'));
      expect(jsonStr, contains('quote'));
      expect(jsonStr, contains('footnote_ref'));
      expect(jsonStr, contains('note_1'));
      expect(jsonStr, contains('note_2'));

      // 4. Lossless FB2 Re-encoding Roundtrip
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      final redecoded = Fb2Converter.fb2ToBook(fb2Bytes);
      expect(redecoded.metadata.title, equals(book.metadata.title));
      expect(redecoded.content.footnotes.length, equals(book.content.footnotes.length));
      GoldenComparator.assertContentEquals(redecoded.content, book.content, context: 'LitRes FB2 Roundtrip');
    });

    test('Parses FB2 2.1 reference sample (code, sub, sup, strike, complex tables, src-title-info)', () async {
      final file = File('test/fixtures/fb2/fb2_21_sample.fb2');
      expect(file.existsSync(), isTrue, reason: 'fb2_21_sample.fb2 fixture must exist');

      final rawBytes = file.readAsBytesSync();
      final book = await DartBook.load(rawBytes, filename: 'fb2_21_sample.fb2');

      // 1. Verify Metadata & src-title-info
      expect(book.metadata.title, equals('FB2 2.1 Specification Reference'));
      expect(book.metadata.language, equals('ru'));
      expect(book.metadata.srcLang, equals('en'));
      expect(book.metadata.srcTitleInfo, isNotNull);
      expect(book.metadata.srcTitleInfo!.title, equals('Computing Machinery and Intelligence'));
      expect(book.metadata.srcTitleInfo!.language, equals('en'));
      expect(book.metadata.srcTitleInfo!.authors.length, equals(1));
      expect(book.metadata.srcTitleInfo!.authors.first.name.display, equals('Alan Mathison Turing'));

      // 2. Verify Key AST Nodes
      final blocks = book.content.blocks;
      expect(blocks.any((b) => b is BookHeading && b.level == 2), isTrue); // subtitle

      final sections = blocks.whereType<BookSection>().toList();
      expect(sections.length, equals(2));

      // Section 1: Formatting & Formulas
      final sec1 = sections[0];
      final p1 = sec1.blocks[0] as BookParagraph;
      expect(p1.inlines.any((i) => i is BookSubscript), isTrue);
      expect(p1.inlines.any((i) => i is BookSuperscript), isTrue);

      final p2 = sec1.blocks[1] as BookParagraph;
      expect(p2.inlines.any((i) => i is BookStrike), isTrue);

      final p3 = sec1.blocks[2] as BookParagraph;
      expect(p3.inlines.any((i) => i is BookCodeSpan), isTrue);
      final codeSpan = p3.inlines.firstWhere((i) => i is BookCodeSpan) as BookCodeSpan;
      expect(codeSpan.code, contains('factorial'));

      expect(sec1.blocks.any((b) => b is BookEmptyLine), isTrue);

      final p4 = sec1.blocks.last as BookParagraph;
      expect(p4.inlines.any((i) => i is BookImageInline), isTrue);
      final inlineImg = p4.inlines.firstWhere((i) => i is BookImageInline) as BookImageInline;
      expect(inlineImg.id, equals('inline-img-01'));
      expect(inlineImg.alt, equals('Code Icon'));
      expect(inlineImg.title, equals('Inline Programming Icon'));

      // Section 2: Complex Tables & Block Image
      final sec2 = sections[1];
      final table = sec2.blocks.firstWhere((b) => b is BookTable) as BookTable;
      expect(table.rows.length, equals(3));
      expect(table.rows[0].cells[0].colSpan, equals(2));
      expect(table.rows[0].cells[0].align, equals('center'));
      expect(table.rows[0].cells[0].vAlign, equals('top'));
      expect(table.rows[0].cells[1].rowSpan, equals(2));
      expect(table.rows[0].cells[1].align, equals('right'));
      expect(table.rows[0].cells[1].vAlign, equals('middle'));
      expect(table.rows[2].cells[1].colSpan, equals(2));

      final quote = sec2.blocks.firstWhere((b) => b is BookQuote) as BookQuote;
      expect((quote.citation.first as BookText).text, equals('Donald Knuth'));

      final blockImg = sec2.blocks.firstWhere((b) => b is BookImageBlock) as BookImageBlock;
      expect(blockImg.id, equals('block-img-01'));
      expect(blockImg.alt, equals('Architecture Diagram'));
      expect(blockImg.title, equals('Figure 1. System Architecture'));

      // 3. Golden JSON serialization
      final goldenJson = GoldenComparator.contentToJson(book.content);
      expect(goldenJson['blocks'], isNotEmpty);

      final jsonStr = jsonEncode(goldenJson);
      expect(jsonStr, contains('subscript'));
      expect(jsonStr, contains('superscript'));
      expect(jsonStr, contains('strike'));
      expect(jsonStr, contains('code_span'));
      expect(jsonStr, contains('table'));
      expect(jsonStr, contains('colSpan'));
      expect(jsonStr, contains('rowSpan'));
      expect(jsonStr, contains('image_inline'));
      expect(jsonStr, contains('image_block'));

      // 4. Lossless FB2 Re-encoding Roundtrip
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      final redecoded = Fb2Converter.fb2ToBook(fb2Bytes);
      expect(redecoded.metadata.title, equals(book.metadata.title));
      expect(redecoded.metadata.srcTitleInfo?.title, equals('Computing Machinery and Intelligence'));
      GoldenComparator.assertContentEquals(redecoded.content, book.content, context: 'FB2 2.1 Roundtrip');
    });

    test('Parses FB2 2.2 sample (style name, custom-info, multiple bodies)', () async {
      final file = File('test/fixtures/fb2/fb2_22_sample.fb2');
      expect(file.existsSync(), isTrue, reason: 'fb2_22_sample.fb2 fixture must exist');

      final rawBytes = file.readAsBytesSync();
      final book = await DartBook.load(rawBytes, filename: 'fb2_22_sample.fb2');

      // 1. Verify Metadata & custom-info
      expect(book.metadata.title, equals('FB2 2.2 Advanced Reference'));
      expect(book.metadata.language, equals('ru'));
      expect(book.metadata.series, isNotEmpty);
      expect(book.metadata.series.first.name, equals('Кибериада'));
      expect(book.metadata.series.first.number, equals(7));
      expect(book.metadata.series.first.url, equals(Uri.parse('https://cybernetics.example.org/series/cyberiada')));
      expect(book.metadata.keywords, containsAll(['наука', 'кибернетика', 'будущее']));

      // 2. Verify Key AST Nodes (NamedStyle & Multiple Bodies)
      final blocks = book.content.blocks;
      expect(blocks, isNotEmpty);

      // Verify style tags in AST
      final sec1 = blocks.whereType<BookSection>().first;
      final p1 = sec1.blocks[0] as BookParagraph;
      final namedStyles = p1.inlines.whereType<BookNamedStyle>().toList();
      expect(namedStyles.length, equals(2));
      expect(namedStyles[0].name, equals('highlight'));
      expect((namedStyles[0].inlines.first as BookText).text, equals('критически важный термин'));
      expect(namedStyles[1].name, equals('term'));
      expect((namedStyles[1].inlines.first as BookText).text, equals('конструкт'));

      final p2 = sec1.blocks[1] as BookParagraph;
      final strong = p2.inlines.firstWhere((i) => i is BookStrong) as BookStrong;
      expect(strong.children.any((c) => c is BookNamedStyle && c.name == 'code-style'), isTrue);

      // Verify multiple bodies (commentary body was parsed into blocks)
      final allSecTitles = blocks.whereType<BookSection>().map((s) => (s.title.first as BookText).text).toList();
      expect(allSecTitles, contains('Комментарий к главе 1'));

      // Verify footnotes body
      expect(book.content.footnotes.length, equals(1));
      expect(book.content.footnotes.first.id, equals('note_lem_1'));

      // 3. Golden JSON serialization
      final goldenJson = GoldenComparator.contentToJson(book.content);
      expect(goldenJson['blocks'], isNotEmpty);

      final jsonStr = jsonEncode(goldenJson);
      expect(jsonStr, contains('named_style'));
      expect(jsonStr, contains('highlight'));
      expect(jsonStr, contains('code-style'));

      // 4. Lossless FB2 Re-encoding Roundtrip
      final fb2Bytes = await Fb2Converter.bookToFb2(book);
      final redecoded = Fb2Converter.fb2ToBook(fb2Bytes);
      expect(redecoded.metadata.title, equals(book.metadata.title));
      expect(redecoded.metadata.series.first.url, equals(Uri.parse('https://cybernetics.example.org/series/cyberiada')));
      GoldenComparator.assertContentEquals(redecoded.content, book.content, context: 'FB2 2.2 Roundtrip');
    });
  });
}
