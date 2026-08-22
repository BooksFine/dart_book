import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

import '../../utils/ast_normalizer.dart';
import '../../utils/golden_comparator.dart';

void main() {
  group('Fb2Parser Unit Tests', () {
    late Fb2Parser parser;

    setUp(() {
      parser = Fb2Parser();
    });

    group('1. Section Hierarchy and Arbitrary Depth', () {
      test('Parses multi-level nested sections with IDs and titles', () {
        const xml = '''
          <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
            <body>
              <section id="vol-1">
                <title><p>Volume 1: Origins</p></title>
                <p>Introductory paragraph of Volume 1.</p>
                <section id="ch-1">
                  <title><p>Chapter 1: The Gathering</p></title>
                  <p>First paragraph of Chapter 1.</p>
                  <section id="sec-1-1">
                    <title><p>Section 1.1: Dawn</p></title>
                    <p>Deep nested text.</p>
                  </section>
                </section>
                <section id="ch-2">
                  <title><p>Chapter 2: The Journey</p></title>
                  <p>Paragraph of Chapter 2.</p>
                </section>
              </section>
            </body>
          </FictionBook>
        ''';

        final blocks = parser.parseFromString(xml);
        expect(blocks.length, equals(1));
        expect(blocks.first, isA<BookSection>());

        // Level 1: Volume 1
        final vol1 = blocks.first as BookSection;
        expect(vol1.id, equals('vol-1'));
        expect(vol1.title.length, equals(1));
        expect(
          (vol1.title.first as BookText).text,
          equals('Volume 1: Origins'),
        );
        expect(vol1.blocks.length, equals(3)); // 1 paragraph + 2 child sections

        expect(vol1.blocks[0], isA<BookParagraph>());
        expect(
          ((vol1.blocks[0] as BookParagraph).inlines.first as BookText).text,
          equals('Introductory paragraph of Volume 1.'),
        );

        // Level 2: Chapter 1
        expect(vol1.blocks[1], isA<BookSection>());
        final ch1 = vol1.blocks[1] as BookSection;
        expect(ch1.id, equals('ch-1'));
        expect(
          (ch1.title.first as BookText).text,
          equals('Chapter 1: The Gathering'),
        );
        expect(ch1.blocks.length, equals(2)); // 1 paragraph + 1 child section

        // Level 3: Section 1.1
        expect(ch1.blocks[1], isA<BookSection>());
        final sec11 = ch1.blocks[1] as BookSection;
        expect(sec11.id, equals('sec-1-1'));
        expect(
          (sec11.title.first as BookText).text,
          equals('Section 1.1: Dawn'),
        );
        expect(sec11.blocks.length, equals(1));
        expect(
          ((sec11.blocks[0] as BookParagraph).inlines.first as BookText).text,
          equals('Deep nested text.'),
        );

        // Level 2: Chapter 2
        expect(vol1.blocks[2], isA<BookSection>());
        final ch2 = vol1.blocks[2] as BookSection;
        expect(ch2.id, equals('ch-2'));
        expect(
          (ch2.title.first as BookText).text,
          equals('Chapter 2: The Journey'),
        );
      });

      test('Parses section without ID and subtitle/empty-line elements', () {
        const xml = '''
          <section>
            <subtitle><p>Subtitle of Section</p></subtitle>
            <p>First line</p>
            <empty-line/>
            <p>Second line after empty line</p>
          </section>
        ''';

        final blocks = parser.parseFromString(xml);
        expect(blocks.length, equals(1));
        final section = blocks.first as BookSection;
        expect(section.id, isNull);
        expect(section.title, isEmpty);
        expect(section.blocks.length, equals(4));

        expect(section.blocks[0], isA<BookHeading>());
        final subtitle = section.blocks[0] as BookHeading;
        expect(subtitle.level, equals(2));
        expect(
          (subtitle.text.first as BookText).text,
          equals('Subtitle of Section'),
        );

        expect(section.blocks[1], isA<BookParagraph>());
        expect(section.blocks[2], isA<BookEmptyLine>());
        expect(section.blocks[3], isA<BookParagraph>());
      });
    });

    group('2. Epigraphs and Quotes with Poems & Authors', () {
      test('Parses <epigraph> with paragraphs, poems, and text-author', () {
        const xml = '''
          <epigraph>
            <p>Knowledge is a journey, not a destination.</p>
            <poem>
              <stanza>
                <v>The woods are lovely, dark and deep,</v>
                <v>But I have promises to keep.</v>
              </stanza>
            </poem>
            <text-author>Robert Frost</text-author>
          </epigraph>
        ''';

        final blocks = parser.parseFromString(xml);
        expect(blocks.length, equals(1));
        expect(blocks.first, isA<BookQuote>());

        final epigraph = blocks.first as BookQuote;
        expect(epigraph.attributes['fb2-type'], equals('epigraph'));
        expect(epigraph.citation.length, equals(1));
        expect(
          (epigraph.citation.first as BookText).text,
          equals('Robert Frost'),
        );

        expect(epigraph.blocks.length, equals(2));
        expect(epigraph.blocks[0], isA<BookParagraph>());
        expect(
          ((epigraph.blocks[0] as BookParagraph).inlines.first as BookText)
              .text,
          equals('Knowledge is a journey, not a destination.'),
        );

        expect(epigraph.blocks[1], isA<BookPoem>());
        final poem = epigraph.blocks[1] as BookPoem;
        expect(poem.stanzas.length, equals(1));
        expect(poem.stanzas[0].lines.length, equals(2));
        expect(
          (poem.stanzas[0].lines[0].inlines.first as BookText).text,
          equals('The woods are lovely, dark and deep,'),
        );
        expect(
          (poem.stanzas[0].lines[1].inlines.first as BookText).text,
          equals('But I have promises to keep.'),
        );
      });

      test(
        'Parses <cite> with multiple paragraphs and text-author without epigraph attribute',
        () {
          const xml = '''
          <cite>
            <p>Science is organized knowledge.</p>
            <p>Wisdom is organized life.</p>
            <text-author>Immanuel Kant</text-author>
          </cite>
        ''';

          final blocks = parser.parseFromString(xml);
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookQuote>());

          final quote = blocks.first as BookQuote;
          expect(quote.attributes.containsKey('fb2-type'), isFalse);
          expect(quote.blocks.length, equals(2));
          expect(
            (quote.citation.first as BookText).text,
            equals('Immanuel Kant'),
          );
        },
      );
    });

    group('3. Footnotes and Links', () {
      test(
        'Parses footnote links with type="note", #n_, #note prefixes into BookFootnoteRef',
        () {
          const xml = '''
          <p>
            Standard note: <a type="note" l:href="#fn_1">[1]</a>.
            Prefix n_ note: <a l:href="#n_2">[2]</a>.
            Prefix note_ note: <a l:href="#note_3">[3]</a>.
            External link: <a l:href="https://dart.dev">Dart Website</a>.
          </p>
        ''';

          final blocks = parser.parseFromString(xml);
          expect(blocks.length, equals(1));
          final p = blocks.first as BookParagraph;

          final fnRefs = p.inlines.whereType<BookFootnoteRef>().toList();
          expect(fnRefs.length, equals(3));

          expect(fnRefs[0].id, equals('fn_1'));
          expect((fnRefs[0].label.first as BookText).text, equals('[1]'));

          expect(fnRefs[1].id, equals('n_2'));
          expect((fnRefs[1].label.first as BookText).text, equals('[2]'));

          expect(fnRefs[2].id, equals('note_3'));
          expect((fnRefs[2].label.first as BookText).text, equals('[3]'));

          final links = p.inlines.whereType<BookLink>().toList();
          expect(links.length, equals(1));
          expect(links.first.href, equals(Uri.parse('https://dart.dev')));
          expect(
            (links.first.children.first as BookText).text,
            equals('Dart Website'),
          );
        },
      );
    });

    group('4. Custom Styles (<style name="...">)', () {
      test(
        'Parses <style name="..."> into BookNamedStyle preserving nested inlines',
        () {
          const xml = '''
          <p>
            Standard text with <style name="highlight-red">red <strong>bold</strong> text</style> and more.
          </p>
        ''';

          final blocks = parser.parseFromString(xml);
          expect(blocks.length, equals(1));
          final p = blocks.first as BookParagraph;

          expect(p.inlines.any((i) => i is BookNamedStyle), isTrue);
          final style =
              p.inlines.firstWhere((i) => i is BookNamedStyle)
                  as BookNamedStyle;
          expect(style.name, equals('highlight-red'));
          expect(style.inlines.length, equals(3));
          expect((style.inlines[0] as BookText).text, equals('red '));
          expect(style.inlines[1], isA<BookStrong>());
          expect(
            ((style.inlines[1] as BookStrong).children.first as BookText).text,
            equals('bold'),
          );
          expect((style.inlines[2] as BookText).text, equals(' text'));
        },
      );

      test(
        'Flattens <style> without name attribute without wrapping in BookNamedStyle',
        () {
          const xml =
              '<p>Text with <style><emphasis>anonymous style</emphasis></style> text.</p>';
          final blocks = parser.parseFromString(xml);
          final p = blocks.first as BookParagraph;

          expect(p.inlines.any((i) => i is BookNamedStyle), isFalse);
          expect(p.inlines.any((i) => i is BookEmphasis), isTrue);
        },
      );
    });

    group('5. Images and Tables with Attributes', () {
      test(
        'Parses block and inline images with id, alt, title, and l:href / href attributes',
        () {
          const xml = '''
          <section>
            <image id="img-block-1" l:href="#figure1.png" alt="Architecture Diagram" title="Figure 1"/>
            <p>
              Inline icon: <image id="img-inline-1" href="#icon.svg" alt="Star Icon" title="Rating star"/> in text.
            </p>
          </section>
        ''';

          final blocks = parser.parseFromString(xml);
          final section = blocks.first as BookSection;

          // Block image
          expect(section.blocks[0], isA<BookImageBlock>());
          final blockImg = section.blocks[0] as BookImageBlock;
          expect(blockImg.id, equals('img-block-1'));
          expect(blockImg.ref.id, equals('figure1.png'));
          expect(blockImg.alt, equals('Architecture Diagram'));
          expect(blockImg.title, equals('Figure 1'));

          // Inline image
          final p = section.blocks[1] as BookParagraph;
          final inlineImg = p.inlines.whereType<BookImageInline>().first;
          expect(inlineImg.id, equals('img-inline-1'));
          expect(inlineImg.ref.id, equals('icon.svg'));
          expect(inlineImg.alt, equals('Star Icon'));
          expect(inlineImg.title, equals('Rating star'));
        },
      );

      test('Uses custom BookResourceRegistrar if provided', () {
        final registered = <String>[];
        final customParser = Fb2Parser(
          registrar: (href, {required isInline}) {
            registered.add(href);
            return 'custom_mapped_$href';
          },
        );

        const xml = '<image l:href="#photo.jpg" alt="Photo"/>';
        final blocks = customParser.parseFromString(xml);

        expect(registered, contains('#photo.jpg'));
        expect(
          (blocks.first as BookImageBlock).ref.id,
          equals('custom_mapped_#photo.jpg'),
        );
      });

      test(
        'Parses tables with colspan, rowspan, align, and valign attributes',
        () {
          const xml = '''
          <table>
            <tr>
              <th colspan="2" rowspan="1" align="center" valign="top"><p>Header 1+2</p></th>
              <th rowspan="2" align="right" valign="bottom"><p>Header 3</p></th>
            </tr>
            <tr>
              <td align="left" valign="middle"><p>Cell 2.1</p></td>
              <td align="justify"><p>Cell 2.2</p></td>
            </tr>
          </table>
        ''';

          final blocks = parser.parseFromString(xml);
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookTable>());

          final table = blocks.first as BookTable;
          expect(table.rows.length, equals(2));

          // Row 0
          final r0 = table.rows[0];
          expect(r0.cells.length, equals(2));
          expect(r0.cells[0].colSpan, equals(2));
          expect(r0.cells[0].rowSpan, isNull); // 1 is normalized to null
          expect(r0.cells[0].align, equals('center'));
          expect(r0.cells[0].vAlign, equals('top'));

          expect(r0.cells[1].colSpan, isNull);
          expect(r0.cells[1].rowSpan, equals(2));
          expect(r0.cells[1].align, equals('right'));
          expect(r0.cells[1].vAlign, equals('bottom'));

          // Row 1
          final r1 = table.rows[1];
          expect(r1.cells.length, equals(2));
          expect(r1.cells[0].align, equals('left'));
          expect(r1.cells[0].vAlign, equals('middle'));
          expect(r1.cells[1].align, equals('justify'));
        },
      );
    });

    group('6. Code Blocks and Inline Formatting', () {
      test('Parses <code> and <pre> as BookCodeBlock', () {
        const xmlCode = '<code>void main() {\n  print(42);\n}</code>';
        final blocksCode = parser.parseFromString(xmlCode);
        expect(blocksCode.length, equals(1));
        expect(blocksCode.first, isA<BookCodeBlock>());
        expect(
          (blocksCode.first as BookCodeBlock).code,
          contains('print(42);'),
        );

        const xmlPre = '<pre>const pi = 3.14159;</pre>';
        final blocksPre = parser.parseFromString(xmlPre);
        expect(blocksPre.length, equals(1));
        expect(blocksPre.first, isA<BookCodeBlock>());
        expect(
          (blocksPre.first as BookCodeBlock).code,
          equals('const pi = 3.14159;'),
        );
      });

      test(
        'Parses strong, emphasis, strikethrough/strike, sub, sup, and inline code',
        () {
          const xml = '''
          <p>
            <strong>Bold</strong>,
            <emphasis>Italic</emphasis>,
            <strikethrough>Deleted</strikethrough>,
            <strike>Strike</strike>,
            <sub>Sub</sub>,
            <sup>Sup</sup>,
            <code>int x = 0;</code>
          </p>
        ''';

          final blocks = parser.parseFromString(xml);
          final p = blocks.first as BookParagraph;

          expect(p.inlines.any((i) => i is BookStrong), isTrue);
          expect(p.inlines.any((i) => i is BookEmphasis), isTrue);
          expect(p.inlines.whereType<BookStrike>().length, equals(2));
          expect(p.inlines.any((i) => i is BookSubscript), isTrue);
          expect(p.inlines.any((i) => i is BookSuperscript), isTrue);
          expect(
            p.inlines.any((i) => i is BookCodeSpan && i.code == 'int x = 0;'),
            isTrue,
          );
        },
      );
    });

    group('7. Strict Mode & Logger Handling', () {
      test('Throws BookParseException in strictMode on unhandled tag', () {
        final strictParser = Fb2Parser(strictMode: true);
        const xml = '<unsupported-fb2-tag><p>Text</p></unsupported-fb2-tag>';

        expect(
          () => strictParser.parseFromString(xml),
          throwsA(isA<BookParseException>()),
        );
      });

      test(
        'Logs warning and parses children in non-strict mode for unhandled tag',
        () {
          final warnings = <String>[];
          final lenientParser = Fb2Parser(
            strictMode: false,
            logger: (w) => warnings.add(w),
          );

          const xml =
              '<custom-wrapper><p>Paragraph inside wrapper</p></custom-wrapper>';
          final blocks = lenientParser.parseFromString(xml);

          expect(warnings.isNotEmpty, isTrue);
          expect(warnings.first, contains('custom-wrapper'));
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookParagraph>());
          expect(
            ((blocks.first as BookParagraph).inlines.first as BookText).text,
            equals('Paragraph inside wrapper'),
          );
        },
      );
    });

    group('8. AstNormalizer and GoldenComparator Integration', () {
      test('Normalizes AST and performs golden JSON comparison', () {
        const xml = '<p>First <strong>bold</strong> text.</p>';
        final blocks = parser.parseFromString(xml);
        final content = BookContent(blocks: blocks);

        final normalized = AstNormalizer.normalizeContent(content);
        expect(normalized.blocks.length, equals(1));

        final expectedContent = BookContent(
          blocks: [
            BookParagraph(
              inlines: [
                const BookText('First '),
                const BookStrong(children: [BookText('bold')]),
                const BookText(' text.'),
              ],
            ),
          ],
        );

        GoldenComparator.assertContentEquals(content, expectedContent);
      });
    });

    group(
      '9. Multiple Text-Authors, Inline Empty-Lines, and Robust URI Parsing',
      () {
        test('Parses epigraph and cite with multiple text-author elements', () {
          const xml = '''
        <epigraph>
          <p>Цитата эпиграфа</p>
          <text-author>Автор Первый</text-author>
          <text-author>Автор Второй (перевод)</text-author>
        </epigraph>
        ''';
          final blocks = parser.parseFromString(xml);
          expect(blocks.length, equals(1));
          final epigraph = blocks[0] as BookQuote;
          final citationText = epigraph.citation
              .whereType<BookText>()
              .map((t) => t.text)
              .join();
          expect(
            citationText,
            contains('Автор Первый, Автор Второй (перевод)'),
          );
        });

        test('Parses inline empty-line inside paragraph as BookLineBreak', () {
          const xml = '<p>Строка 1<empty-line/>Строка 2</p>';
          final blocks = parser.parseFromString(xml);
          expect(blocks.length, equals(1));
          final p = blocks[0] as BookParagraph;
          expect(p.inlines.length, equals(3));
          expect((p.inlines[0] as BookText).text, equals('Строка 1'));
          expect(p.inlines[1], isA<BookLineBreak>());
          expect((p.inlines[2] as BookText).text, equals('Строка 2'));
        });

        test(
          'Gracefully parses malformed links without throwing FormatException',
          () {
            const xml =
                '<p><a l:href="ht tp://invalid uri with spaces">Link</a></p>';
            final blocks = parser.parseFromString(xml);
            expect(blocks.length, equals(1));
            final p = blocks[0] as BookParagraph;
            expect(p.inlines.first, isA<BookLink>());
          },
        );
      },
    );
  });
}
