import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import 'ast_normalizer.dart';

/// Утилита для сериализации AST в JSON-снимки и детального сравнения.
class GoldenComparator {
  /// Преобразует [BookContent] в структурированный `Map<String, dynamic>`.
  static Map<String, dynamic> contentToJson(BookContent content, {bool normalize = true}) {
    final norm = normalize ? AstNormalizer.normalizeContent(content) : content;
    return {
      'blocks': norm.blocks.map(blockToJson).toList(),
      'footnotes': norm.footnotes.map((fn) => {
        'id': fn.id,
        'blocks': fn.blocks.map(blockToJson).toList(),
      }).toList(),
    };
  }

  /// Преобразует [BookBlock] в JSON.
  static Map<String, dynamic> blockToJson(BookBlock block) {
    return switch (block) {
      BookParagraph p => {
          'type': 'paragraph',
          'inlines': p.inlines.map(inlineToJson).toList(),
        },
      BookHeading h => {
          'type': 'heading',
          'level': h.level,
          'text': h.text.map(inlineToJson).toList(),
        },
      BookSection s => {
          'type': 'section',
          if (s.id != null) 'id': s.id,
          'title': s.title.map(inlineToJson).toList(),
          'blocks': s.blocks.map(blockToJson).toList(),
          if (s.children.isNotEmpty)
            'children': s.children.map(blockToJson).toList(),
        },
      BookQuote q => {
          'type': 'quote',
          'blocks': q.blocks.map(blockToJson).toList(),
          if (q.citation.isNotEmpty)
            'citation': q.citation.map(inlineToJson).toList(),
        },
      BookList l => {
          'type': 'list',
          'ordered': l.ordered,
          'items': l.items
              .map((it) => {'blocks': it.blocks.map(blockToJson).toList()})
              .toList(),
        },
      BookTable t => {
          'type': 'table',
          'rows': t.rows
              .map(
                (r) => {
                  'cells': r.cells
                      .map(
                        (c) => {
                          if (c.colSpan != null && c.colSpan! > 1) 'colSpan': c.colSpan,
                          if (c.rowSpan != null && c.rowSpan! > 1) 'rowSpan': c.rowSpan,
                          if (c.align != null) 'align': c.align,
                          if (c.vAlign != null) 'vAlign': c.vAlign,
                          'blocks': c.blocks.map(blockToJson).toList(),
                        },
                      )
                      .toList(),
                },
              )
              .toList(),
        },
      BookPoem p => {
          'type': 'poem',
          'stanzas': p.stanzas
              .map(
                (s) => {
                  'lines': s.lines
                      .map((l) => {'inlines': l.inlines.map(inlineToJson).toList()})
                      .toList(),
                },
              )
              .toList(),
        },
      BookCodeBlock c => {
          'type': 'code_block',
          'code': c.code,
          if (c.language != null) 'language': c.language,
        },
      BookImageBlock img => {
          'type': 'image_block',
          'ref': img.ref.id,
          if (img.id != null) 'id': img.id,
          if (img.alt != null) 'alt': img.alt,
          if (img.title != null) 'title': img.title,
        },
      BookAudioBlock a => {
          'type': 'audio_block',
          'ref': a.ref.id,
        },
      BookVideoBlock v => {
          'type': 'video_block',
          'ref': v.ref.id,
        },
      BookMathBlock m => {
          'type': 'math_block',
          'mathml': m.mathml,
        },
      BookSvgBlock svg => {
          'type': 'svg_block',
          'svg': svg.svg,
        },
      BookHorizontalRule _ => {'type': 'horizontal_rule'},
      BookEmptyLine _ => {'type': 'empty_line'},
      BookRawHtmlBlock raw => {'type': 'raw_html', 'html': raw.html},
      BookRawXmlBlock raw => {'type': 'raw_xml', 'xml': raw.xml},
    };
  }

  /// Преобразует [BookInline] в JSON.
  static Map<String, dynamic> inlineToJson(BookInline inline) {
    return switch (inline) {
      BookText t => {'type': 'text', 'text': t.text},
      BookEmphasis e => {
          'type': 'emphasis',
          'children': e.children.map(inlineToJson).toList(),
        },
      BookStrong s => {
          'type': 'strong',
          'children': s.children.map(inlineToJson).toList(),
        },
      BookStrike st => {
          'type': 'strike',
          'children': st.children.map(inlineToJson).toList(),
        },
      BookCodeSpan c => {'type': 'code_span', 'code': c.code},
      BookNamedStyle ns => {
          'type': 'named_style',
          'name': ns.name,
          'inlines': ns.inlines.map(inlineToJson).toList(),
        },
      BookLink l => {
          'type': 'link',
          'href': l.href.toString(),
          'children': l.children.map(inlineToJson).toList(),
        },
      BookAnchor a => {'type': 'anchor', 'id': a.id},
      BookImageInline img => {
          'type': 'image_inline',
          'ref': img.ref.id,
          if (img.id != null) 'id': img.id,
          if (img.alt != null) 'alt': img.alt,
          if (img.title != null) 'title': img.title,
        },
      BookFootnoteRef fn => {
          'type': 'footnote_ref',
          'id': fn.id,
          if (fn.label.isNotEmpty)
            'label': fn.label.map(inlineToJson).toList(),
        },
      BookSuperscript sup => {
          'type': 'superscript',
          'children': sup.children.map(inlineToJson).toList(),
        },
      BookSubscript sub => {
          'type': 'subscript',
          'children': sub.children.map(inlineToJson).toList(),
        },
      BookLineBreak _ => {'type': 'line_break'},
      BookRawHtmlInline raw => {'type': 'raw_html_inline', 'html': raw.html},
      BookRawXmlInline raw => {'type': 'raw_xml_inline', 'xml': raw.xml},
    };
  }

  /// Сравнивает два [BookContent] через JSON-нормализацию.
  static void assertContentEquals(BookContent actual, BookContent expected, {String? context}) {
    final actualJson = contentToJson(actual);
    final expectedJson = contentToJson(expected);

    expect(
      actualJson,
      equals(expectedJson),
      reason: context != null ? 'AST mismatch in context: $context' : null,
    );
  }
}
