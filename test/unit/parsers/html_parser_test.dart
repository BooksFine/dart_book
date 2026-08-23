import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

import '../../utils/ast_normalizer.dart';
import '../../utils/golden_comparator.dart';

void main() {
  group('HtmlParser Unit Tests', () {
    late HtmlParser parser;

    setUp(() {
      parser = HtmlParser();
    });

    test('Parses plain text with newline-separated paragraphs and indents correctly', () {
      const html = '''
        <div class="part_text">
          &nbsp;&nbsp;&nbsp;&nbsp;Первый абзац текста фанфика с <i>курсивом</i> внутри.
          &nbsp;&nbsp;&nbsp;&nbsp;Второй абзац текста фанфика с <b>жирным</b> шрифтом.
          &nbsp;&nbsp;&nbsp;&nbsp;Третий абзац диалога:
          - Привет! - сказал герой.
          - Здравствуй! - ответила героиня.
        </div>
      ''';
      final blocks = parser.parseFromString(html);
      expect(blocks.length, equals(5));
      for (final block in blocks) {
        expect(block, isA<BookParagraph>());
      }
      expect(((blocks[0] as BookParagraph).inlines.first as BookText).text, contains('Первый абзац'));
      expect(((blocks[1] as BookParagraph).inlines.first as BookText).text, contains('Второй абзац'));
      expect(((blocks[2] as BookParagraph).inlines.first as BookText).text, contains('Третий абзац'));
      expect(((blocks[3] as BookParagraph).inlines.first as BookText).text, contains('- Привет!'));
      expect(((blocks[4] as BookParagraph).inlines.first as BookText).text, contains('- Здравствуй!'));
    });

    group('1. Nested and Complex Lists', () {
      test('Parses ordered list with nested unordered and ordered lists', () {
        const html = '''
          <ol>
            <li>
              <p>Item 1</p>
              <ul>
                <li>Subitem 1.1</li>
                <li>
                  <p>Subitem 1.2</p>
                  <ol>
                    <li>Deep 1.2.1</li>
                  </ol>
                </li>
              </ul>
            </li>
            <li>Item 2</li>
          </ol>
        ''';

        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        expect(blocks.first, isA<BookList>());

        final rootList = blocks.first as BookList;
        expect(rootList.ordered, isTrue);
        expect(rootList.items.length, equals(2));

        // Item 1 contains Paragraph and nested unordered list
        final item1Blocks = rootList.items[0].blocks;
        expect(item1Blocks.length, equals(2));
        expect(item1Blocks[0], isA<BookParagraph>());
        expect(
          (item1Blocks[0] as BookParagraph).inlines.first,
          isA<BookText>(),
        );
        expect(
          ((item1Blocks[0] as BookParagraph).inlines.first as BookText).text,
          equals('Item 1'),
        );

        expect(item1Blocks[1], isA<BookList>());
        final nestedUl = item1Blocks[1] as BookList;
        expect(nestedUl.ordered, isFalse);
        expect(nestedUl.items.length, equals(2));

        // Subitem 1.2 contains paragraph and nested ordered list
        final subitem2Blocks = nestedUl.items[1].blocks;
        expect(subitem2Blocks.length, equals(2));
        expect(subitem2Blocks[0], isA<BookParagraph>());
        expect(subitem2Blocks[1], isA<BookList>());

        final deepOl = subitem2Blocks[1] as BookList;
        expect(deepOl.ordered, isTrue);
        expect(deepOl.items.length, equals(1));
        final deepText =
            ((deepOl.items[0].blocks.first as BookParagraph).inlines.first
                    as BookText)
                .text;
        expect(deepText, equals('Deep 1.2.1'));

        // Item 2
        final item2Blocks = rootList.items[1].blocks;
        expect(item2Blocks.length, equals(1));
        expect(
          ((item2Blocks[0] as BookParagraph).inlines.first as BookText).text,
          equals('Item 2'),
        );
      });

      test('Parses list items containing blockquotes and citations', () {
        const html = '''
          <ul>
            <li>
              <blockquote>
                <p>Knowledge is power.</p>
                <cite>Francis Bacon</cite>
              </blockquote>
            </li>
          </ul>
        ''';

        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        expect(blocks.first, isA<BookList>());

        final list = blocks.first as BookList;
        expect(list.ordered, isFalse);
        expect(list.items.length, equals(1));

        final itemBlocks = list.items.first.blocks;
        expect(itemBlocks.length, equals(1));
        expect(itemBlocks.first, isA<BookQuote>());

        final quote = itemBlocks.first as BookQuote;
        expect(quote.blocks.length, equals(1));
        expect(quote.blocks.first, isA<BookParagraph>());
        expect(
          ((quote.blocks.first as BookParagraph).inlines.first as BookText)
              .text,
          equals('Knowledge is power.'),
        );
        expect(quote.citation.length, equals(1));
        expect(
          (quote.citation.first as BookText).text,
          equals('Francis Bacon'),
        );
      });

      test('Parses lists containing code blocks and headings', () {
        const html = '''
          <ul>
            <li>
              <h2>Section Title</h2>
              <pre><code class="language-dart">final x = 42;</code></pre>
            </li>
          </ul>
        ''';

        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        final list = blocks.first as BookList;
        final itemBlocks = list.items.first.blocks;

        expect(itemBlocks.length, equals(2));
        expect(itemBlocks[0], isA<BookHeading>());
        expect((itemBlocks[0] as BookHeading).level, equals(2));
        expect(itemBlocks[1], isA<BookCodeBlock>());
        final codeBlock = itemBlocks[1] as BookCodeBlock;
        expect(codeBlock.language, equals('dart'));
        expect(codeBlock.code, contains('final x = 42;'));
      });
    });

    group('2. Complex Tables', () {
      test(
        'Parses table with thead, tbody, tfoot, colspan, rowspan, align, and valign',
        () {
          const html = '''
          <table>
            <thead>
              <tr>
                <th colspan="2" rowspan="1" align="center" valign="top">Header 1+2</th>
                <th rowspan="2" align="right" valign="bottom">Header 3</th>
              </tr>
              <tr>
                <th>Subheader 1</th>
                <th>Subheader 2</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td align="left" valign="middle">Data 1.1</td>
                <td align="justify">Data 1.2</td>
                <td>Data 1.3</td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <td colspan="3" align="center">Total Summary</td>
              </tr>
            </tfoot>
          </table>
        ''';

          final blocks = parser.parseFromString(html);
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookTable>());

          final table = blocks.first as BookTable;
          expect(table.rows.length, equals(4)); // 2 thead + 1 tbody + 1 tfoot

          // Row 0
          final row0 = table.rows[0];
          expect(row0.cells.length, equals(2));
          expect(row0.cells[0].colSpan, equals(2));
          expect(row0.cells[0].rowSpan, equals(1));
          expect(row0.cells[0].align, equals('center'));
          expect(row0.cells[0].vAlign, equals('top'));
          expect(
            ((row0.cells[0].blocks.first as BookParagraph).inlines.first
                    as BookText)
                .text,
            equals('Header 1+2'),
          );

          expect(row0.cells[1].colSpan, isNull);
          expect(row0.cells[1].rowSpan, equals(2));
          expect(row0.cells[1].align, equals('right'));
          expect(row0.cells[1].vAlign, equals('bottom'));

          // Row 1
          final row1 = table.rows[1];
          expect(row1.cells.length, equals(2));

          // Row 2 (tbody)
          final row2 = table.rows[2];
          expect(row2.cells.length, equals(3));
          expect(row2.cells[0].align, equals('left'));
          expect(row2.cells[0].vAlign, equals('middle'));
          expect(row2.cells[1].align, equals('justify'));

          // Row 3 (tfoot)
          final row3 = table.rows[3];
          expect(row3.cells.length, equals(1));
          expect(row3.cells[0].colSpan, equals(3));
          expect(row3.cells[0].align, equals('center'));
        },
      );

      test(
        'Parses inline CSS styles for text-align and vertical-align in table cells',
        () {
          const html = '''
          <table>
            <tr>
              <td style="text-align: center; vertical-align: top;">Styled Cell 1</td>
              <td style="text-align: right; vertical-align: baseline;">Styled Cell 2</td>
            </tr>
          </table>
        ''';

          final blocks = parser.parseFromString(html);
          final table = blocks.first as BookTable;
          final row = table.rows.first;

          expect(row.cells[0].align, equals('center'));
          expect(row.cells[0].vAlign, equals('top'));

          expect(row.cells[1].align, equals('right'));
          expect(row.cells[1].vAlign, equals('baseline'));
        },
      );

      test(
        'Parses multi-block content (paragraphs, lists) inside table cells',
        () {
          const html = '''
          <table>
            <tr>
              <td>
                <p>Paragraph in cell</p>
                <ul>
                  <li>List item in cell</li>
                </ul>
              </td>
            </tr>
          </table>
        ''';

          final blocks = parser.parseFromString(html);
          final table = blocks.first as BookTable;
          final cellBlocks = table.rows.first.cells.first.blocks;

          expect(cellBlocks.length, equals(2));
          expect(cellBlocks[0], isA<BookParagraph>());
          expect(cellBlocks[1], isA<BookList>());
        },
      );
    });

    group('3. Code Blocks & Preformatted Text', () {
      test(
        'Preserves spaces, tabs, and newlines in code blocks with language extraction',
        () {
          const rawCode =
              'void main() {\n  final a = 10;\n\tprint("Hello   World");\n}';
          const html = '<pre><code class="language-dart">$rawCode</code></pre>';

          final blocks = parser.parseFromString(html);
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookCodeBlock>());

          final codeBlock = blocks.first as BookCodeBlock;
          expect(codeBlock.language, equals('dart'));
          expect(codeBlock.code, equals(rawCode));
        },
      );

      test(
        'Extracts language from data-language, lang, and class attributes',
        () {
          const htmlDataLang =
              '<pre data-language="python">x = [1, 2, 3]</pre>';
          final blocks1 = parser.parseFromString(htmlDataLang);
          expect((blocks1.first as BookCodeBlock).language, equals('python'));

          const htmlLang = '<pre lang="rust">fn main() {}</pre>';
          final blocks2 = parser.parseFromString(htmlLang);
          expect((blocks2.first as BookCodeBlock).language, equals('rust'));

          const htmlClassCode =
              '<pre><code class="language-typescript extra-class">const a = 1;</code></pre>';
          final blocks3 = parser.parseFromString(htmlClassCode);
          expect(
            (blocks3.first as BookCodeBlock).language,
            equals('typescript'),
          );
        },
      );

      test('Decodes HTML entities inside preformatted code blocks', () {
        const html =
            '<pre><code>if (a &lt; b &amp;&amp; b &gt; 0) { return &quot;ok&quot;; }</code></pre>';
        final blocks = parser.parseFromString(html);

        final codeBlock = blocks.first as BookCodeBlock;
        expect(codeBlock.code, equals('if (a < b && b > 0) { return "ok"; }'));
      });
    });

    group('4. Poems and Blockquotes', () {
      test('Parses poem with class="poem", stanzas and lines', () {
        const html = '''
          <div class="poem">
            <div class="stanza">
              <p class="poem-line">Line 1: <em>First stanza</em></p>
              <p class="poem-line">Line 2: <strong>Second verse</strong></p>
            </div>
            <div class="stanza">
              <p class="poem-line">Line 3: Third verse</p>
              <p class="poem-line">Line 4: Fourth verse</p>
            </div>
          </div>
        ''';

        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        expect(blocks.first, isA<BookPoem>());

        final poem = blocks.first as BookPoem;
        expect(poem.stanzas.length, equals(2));

        // Stanza 1
        expect(poem.stanzas[0].lines.length, equals(2));
        final line1Inlines = poem.stanzas[0].lines[0].inlines;
        expect(line1Inlines.any((i) => i is BookEmphasis), isTrue);
        final line2Inlines = poem.stanzas[0].lines[1].inlines;
        expect(line2Inlines.any((i) => i is BookStrong), isTrue);

        // Stanza 2
        expect(poem.stanzas[1].lines.length, equals(2));
      });

      test('Parses blockquote with .citation, cite, or footer tag', () {
        const html = '''
          <blockquote>
            <p>To be, or not to be, that is the question.</p>
            <p>Whether tis nobler in the mind to suffer...</p>
            <cite>William Shakespeare, <em>Hamlet</em></cite>
          </blockquote>
        ''';

        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        expect(blocks.first, isA<BookQuote>());

        final quote = blocks.first as BookQuote;
        expect(quote.blocks.length, equals(2));
        expect(quote.blocks[0], isA<BookParagraph>());
        expect(quote.blocks[1], isA<BookParagraph>());

        expect(quote.citation.isNotEmpty, isTrue);
        expect(quote.citation.any((i) => i is BookEmphasis), isTrue);
        expect(
          quote.citation.whereType<BookText>().map((t) => t.text).join(),
          contains('William Shakespeare'),
        );
      });
    });

    group('5. Arbitrary Inline Nesting & Named Styles', () {
      test(
        'Parses deeply nested inlines: strong -> em -> strike -> code -> sup -> sub',
        () {
          const html =
              '<p><strong>Bold <em>Italic <s>Strike <code>Code <sup>Sup <sub>Sub</sub></sup></code></s></em></strong></p>';

          final blocks = parser.parseFromString(html);
          expect(blocks.length, equals(1));
          final p = blocks.first as BookParagraph;

          expect(p.inlines.first, isA<BookStrong>());
          final strong = p.inlines.first as BookStrong;
          expect(strong.children.any((i) => i is BookEmphasis), isTrue);

          final em =
              strong.children.firstWhere((i) => i is BookEmphasis)
                  as BookEmphasis;
          expect(em.children.any((i) => i is BookStrike), isTrue);

          final strike =
              em.children.firstWhere((i) => i is BookStrike) as BookStrike;
          expect(strike.children.any((i) => i is BookCodeSpan), isTrue);

          final code =
              strike.children.firstWhere((i) => i is BookCodeSpan)
                  as BookCodeSpan;
          expect(code.code, contains('Code'));
        },
      );

      test(
        'Parses span class="style-X" into BookNamedStyle with style name and inner inlines',
        () {
          const html =
              '<p>Normal text <span class="style-custom-accent"><strong>Styled Bold</strong> and plain</span></p>';

          final blocks = parser.parseFromString(html);
          final p = blocks.first as BookParagraph;

          expect(p.inlines.any((i) => i is BookNamedStyle), isTrue);
          final namedStyle =
              p.inlines.firstWhere((i) => i is BookNamedStyle)
                  as BookNamedStyle;
          expect(namedStyle.name, equals('custom-accent'));
          expect(namedStyle.inlines.any((i) => i is BookStrong), isTrue);
        },
      );

      test('Parses EPUB 3 footnote references and anchors correctly', () {
        const html =
            '<p><span id="anchor-1">Here is a reference</span> <a href="#fn10" epub:type="noteref">[10]</a> and another <a href="#fn11" role="doc-noteref">[*]</a>.</p>';

        final blocks = parser.parseFromString(html);
        final p = blocks.first as BookParagraph;

        expect(
          p.inlines.any((i) => i is BookAnchor && i.id == 'anchor-1'),
          isTrue,
        );

        final fnRefs = p.inlines.whereType<BookFootnoteRef>().toList();
        expect(fnRefs.length, equals(2));
        expect(fnRefs[0].id, equals('fn10'));
        expect((fnRefs[0].label.first as BookText).text, equals('[10]'));
        expect(fnRefs[1].id, equals('fn11'));
        expect((fnRefs[1].label.first as BookText).text, equals('[*]'));
      });
    });

    group('6. MathML and SVG Isolation', () {
      test('Isolates MathML into BookMathBlock preserving full XML markup', () {
        const mathml =
            '<math xmlns="http://www.w3.org/1998/Math/MathML"><mrow><msup><mi>a</mi><mn>2</mn></msup><mo>+</mo><msup><mi>b</mi><mn>2</mn></msup><mo>=</mo><msup><mi>c</mi><mn>2</mn></msup></mrow></math>';
        const html = '<p>Formula:</p>$mathml<p>After formula</p>';

        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(3));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookMathBlock>());
        expect(blocks[2], isA<BookParagraph>());

        final mathBlock = blocks[1] as BookMathBlock;
        expect(
          mathBlock.mathml,
          contains('xmlns="http://www.w3.org/1998/Math/MathML"'),
        );
        expect(mathBlock.mathml, contains('<msup><mi>a</mi><mn>2</mn></msup>'));
      });

      test(
        'Isolates SVG graphics into BookSvgBlock preserving SVG structure',
        () {
          const svg =
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" fill="red"/></svg>';
          const html = '<section><h2>Diagram</h2>$svg</section>';

          final blocks = parser.parseFromString(html);
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookSection>());

          final sec = blocks.first as BookSection;
          expect(sec.blocks.length, equals(1));
          expect(sec.blocks.first, isA<BookSvgBlock>());

          final svgBlock = sec.blocks.first as BookSvgBlock;
          expect(svgBlock.svg, contains('<circle cx="50" cy="50" r="40"'));
        },
      );
    });

    group('7. Tolerance to Invalid / Dirty HTML', () {
      test('Handles unclosed tags gracefully', () {
        const dirtyHtml =
            '<p>Paragraph 1 <b>bold without close<p>Paragraph 2 <i>italic unclosed</i>';
        final blocks = parser.parseFromString(dirtyHtml);

        expect(blocks.length, equals(2));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookParagraph>());

        final p1 = blocks[0] as BookParagraph;
        expect(p1.inlines.any((i) => i is BookStrong), isTrue);

        final p2 = blocks[1] as BookParagraph;
        // In HTML5 active formatting element reconstruction, p2 contains <b> which contains <i>
        final hasItalic = p2.inlines.any(
          (i) =>
              i is BookEmphasis ||
              (i is BookStrong && i.children.any((c) => c is BookEmphasis)),
        );
        expect(hasItalic, isTrue);
      });

      test('Handles uppercase HTML tag names', () {
        const upperHtml = '''
          <DIV CLASS="poem">
            <DIV CLASS="stanza">
              <P CLASS="poem-line">Line 1</P>
              <P CLASS="poem-line">Line 2</P>
            </DIV>
          </DIV>
          <TABLE>
            <TR><TD>CELL 1</TD><TD>CELL 2</TD></TR>
          </TABLE>
          <H1>UPPER TITLE</H1>
        ''';

        final blocks = parser.parseFromString(upperHtml);
        expect(blocks.length, equals(3));
        expect(blocks[0], isA<BookPoem>());
        expect(blocks[1], isA<BookTable>());
        expect(blocks[2], isA<BookHeading>());
        expect((blocks[2] as BookHeading).level, equals(1));
      });

      test('Decodes all standard and numeric HTML entities', () {
        const html =
            '<p>&quot;Hello &amp; welcome &mdash; 5 &gt; 3 &amp;&amp; 2 &lt; 4 &apos;copyright&apos; &copy; 2026&#33;&quot;</p>';
        final blocks = parser.parseFromString(html);

        final p = blocks.first as BookParagraph;
        final text = (p.inlines.first as BookText).text;
        expect(
          text,
          equals('"Hello & welcome — 5 > 3 && 2 < 4 \'copyright\' © 2026!"'),
        );
      });
    });

    group('8. Strict Mode and Logger Integration', () {
      test(
        'Throws BookParseException in strictMode for unknown custom element',
        () {
          final strictParser = HtmlParser(strictMode: true);
          const html =
              '<custom-unsupported-tag>Content</custom-unsupported-tag>';

          expect(
            () => strictParser.parseFromString(html),
            throwsA(isA<BookParseException>()),
          );
        },
      );

      test(
        'Logs warning and produces BookRawHtmlBlock in non-strict mode for unknown element',
        () {
          final warnings = <String>[];
          final lenientParser = HtmlParser(
            strictMode: false,
            logger: (w) => warnings.add(w),
          );

          const html =
              '<custom-widget data-prop="val">Custom Widget Content</custom-widget>';
          final blocks = lenientParser.parseFromString(html);

          expect(warnings.isNotEmpty, isTrue);
          expect(warnings.first, contains('custom-widget'));
          expect(blocks.length, equals(1));
          expect(blocks.first, isA<BookRawHtmlBlock>());
          expect(
            (blocks.first as BookRawHtmlBlock).html,
            contains('custom-widget'),
          );
        },
      );
    });

    group('9. GoldenComparator and AST Normalization', () {
      test('Normalized AST produces identical JSON representation', () {
        const html = '<p>Hello <span>world</span> <b>today</b>!</p>';
        final blocks = parser.parseFromString(html);
        final content = BookContent(blocks: blocks);

        final normalized = AstNormalizer.normalizeContent(content);
        expect(normalized.blocks.length, equals(1));

        final json = GoldenComparator.contentToJson(content);
        expect(json['blocks'], isNotEmpty);

        // Golden comparison with expected structure
        final expectedContent = BookContent(
          blocks: [
            BookParagraph(
              inlines: [
                const BookText('Hello world '),
                const BookStrong(children: [BookText('today')]),
                const BookText('!'),
              ],
            ),
          ],
        );

        GoldenComparator.assertContentEquals(content, expectedContent);
      });
    });

    group('10. Multimedia, Figures, Line Breaks, and Mixed List Items', () {
      test('Parses audio and video elements with poster and controls', () {
        const html = '''
        <audio src="audio/track.mp3" controls></audio>
        <video src="video/clip.mp4" poster="images/poster.jpg" controls></video>
        ''';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(2));

        final audio = blocks[0] as BookAudioBlock;
        expect(audio.ref.id, equals('audio/track.mp3'));
        expect(audio.controls, isTrue);

        final video = blocks[1] as BookVideoBlock;
        expect(video.ref.id, equals('video/clip.mp4'));
        expect(video.posterRef?.id, equals('images/poster.jpg'));
        expect(video.controls, isTrue);
      });

      test('Parses figure with figcaption and image', () {
        const html = '''
        <figure>
          <img src="img.png" alt="Alt fallback"/>
          <figcaption>Diagram 1. System Architecture</figcaption>
        </figure>
        ''';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        final img = blocks[0] as BookImageBlock;
        expect(img.ref.id, equals('img.png'));
        expect(img.alt, equals('Diagram 1. System Architecture'));
      });

      test('Parses hr and br elements', () {
        const html = '<p>Line 1<br/>Line 2</p><hr/><p>Line 3</p>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(4));
        expect(blocks[0], isA<BookParagraph>());
        expect(((blocks[0] as BookParagraph).inlines.first as BookText).text, equals('Line 1'));
        expect(blocks[1], isA<BookParagraph>());
        expect(((blocks[1] as BookParagraph).inlines.first as BookText).text, equals('Line 2'));
        expect(blocks[2], isA<BookHorizontalRule>());
        expect(blocks[3], isA<BookParagraph>());
      });

      test('Preserves direct text in list items before sublists', () {
        const html = '''
        <ul>
          <li>Parent item text
            <ul>
              <li>Child item</li>
            </ul>
          </li>
        </ul>
        ''';
        final blocks = parser.parseFromString(html);
        final list = blocks[0] as BookList;
        final parentItem = list.items[0];
        expect(parentItem.blocks.length, equals(2));
        final p = parentItem.blocks[0] as BookParagraph;
        final text = (p.inlines.first as BookText).text;
        expect(text, contains('Parent item text'));
        expect(parentItem.blocks[1], isA<BookList>());
      });

      test('Parses multi-class span with style- prefix', () {
        const html =
            '<p><span class="highlight style-red-text active">Styled text</span></p>';
        final blocks = parser.parseFromString(html);
        final p = blocks[0] as BookParagraph;
        final namedStyle = p.inlines.first as BookNamedStyle;
        expect(namedStyle.name, equals('red-text'));
        final text = (namedStyle.inlines.first as BookText).text;
        expect(text, contains('Styled text'));
      });
    });

    group('11. Tag Soup & Malformed HTML Resiliency', () {
      test('Unwraps spans and fonts wrapping block-level paragraphs', () {
        const html = '''
          <span style="font-size: 14px">
            <font color="red">
              <p>Paragraph One</p>
              <p>Paragraph Two</p>
            </font>
          </span>
        ''';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(2));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookParagraph>());
        expect(((blocks[0] as BookParagraph).inlines.first as BookText).text, equals('Paragraph One'));
        expect(((blocks[1] as BookParagraph).inlines.first as BookText).text, equals('Paragraph Two'));
      });

      test('Pushes bold / italic formatting into wrapped paragraphs', () {
        const html = '<b><p>Bold Paragraph 1</p><p>Bold Paragraph 2</p></b>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(2));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookParagraph>());

        final p1 = blocks[0] as BookParagraph;
        expect(p1.inlines.first, isA<BookStrong>());
        expect(((p1.inlines.first as BookStrong).children.first as BookText).text, equals('Bold Paragraph 1'));
      });

      test('Handles mixed text and paragraphs inside divs cleanly', () {
        const html = '<div>Text before <p>Inner paragraph</p> Text after</div>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(3));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookParagraph>());
        expect(blocks[2], isA<BookParagraph>());
        expect(((blocks[0] as BookParagraph).inlines.first as BookText).text.trim(), equals('Text before'));
        expect(((blocks[1] as BookParagraph).inlines.first as BookText).text.trim(), equals('Inner paragraph'));
        expect(((blocks[2] as BookParagraph).inlines.first as BookText).text.trim(), equals('Text after'));
      });

      test('Converts multiple br tags and empty paragraphs into BookEmptyLine', () {
        const html = '<p>P1</p><br/><br/><p><br/></p><p>P2</p>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(5));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookEmptyLine>());
        expect(blocks[2], isA<BookEmptyLine>());
        expect(blocks[3], isA<BookEmptyLine>());
        expect(blocks[4], isA<BookParagraph>());
      });

      test('Unwraps anchor tag wrapping paragraphs', () {
        const html = '<a name="anchor-link"><p>Chapter 1 Heading</p></a>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(1));
        expect(blocks[0], isA<BookParagraph>());
        expect(((blocks[0] as BookParagraph).inlines.first as BookText).text, equals('Chapter 1 Heading'));
      });

      test('Splits <p> with inner <br> and nested <em> into distinct BookParagraph blocks', () {
        const html = '<p><em>First italic line<br/>Second italic line</em></p>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(2));
        expect(blocks[0], isA<BookParagraph>());
        expect(blocks[1], isA<BookParagraph>());

        final p1 = blocks[0] as BookParagraph;
        final p2 = blocks[1] as BookParagraph;
        expect(p1.inlines.first, isA<BookEmphasis>());
        expect(((p1.inlines.first as BookEmphasis).children.first as BookText).text, equals('First italic line'));
        expect(p2.inlines.first, isA<BookEmphasis>());
        expect(((p2.inlines.first as BookEmphasis).children.first as BookText).text, equals('Second italic line'));
      });

      test('Splits text on Unicode line separators (LS \u2028, PS \u2029, NEL \u0085)', () {
        const html = '<p>Line 1\u2028Line 2\u2029Line 3\u0085Line 4</p>';
        final blocks = parser.parseFromString(html);
        expect(blocks.length, equals(4));
        for (var i = 0; i < 4; i++) {
          expect(blocks[i], isA<BookParagraph>());
          expect(((blocks[i] as BookParagraph).inlines.first as BookText).text, equals('Line ${i + 1}'));
        }
      });
    });
  });
}
