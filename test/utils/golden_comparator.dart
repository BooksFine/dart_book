import 'dart:convert';
import 'dart:io';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import 'ast_normalizer.dart';

/// Утилита для сериализации AST в JSON-снимки и детального сравнения с эталонными файлами на диске.
class GoldenComparator {
  /// Сериализует всю книгу [Book] в канонический JSON.
  static Map<String, dynamic> bookToJson(Book book, {bool normalize = true}) {
    final normBook = normalize ? AstNormalizer.normalizeBook(book) : book;
    return {
      'metadata': metadataToJson(normBook.metadata),
      'content': contentToJson(normBook.content, normalize: false),
      'resources': normBook.resources
          .map((r) => {
                'id': r.id,
                'mediaType': r.mediaType,
                'size': r.bytes.length,
              })
          .toList(),
    };
  }

  /// Сериализует метаданные [BookMetadata] в JSON.
  static Map<String, dynamic> metadataToJson(BookMetadata metadata) {
    return {
      'title': metadata.title,
      'id': metadata.id,
      'language': metadata.language,
      'layout': metadata.layout.name,
      if (metadata.srcLang != null) 'srcLang': metadata.srcLang,
      if (metadata.keywords.isNotEmpty) 'keywords': metadata.keywords,
      if (metadata.annotation != null)
        'annotation': contentToJson(metadata.annotation!, normalize: false),
      if (metadata.genres.isNotEmpty)
        'genres': metadata.genres
            .map((g) => {'code': g.code, 'name': g.name})
            .toList(),
      if (metadata.contributors.isNotEmpty)
        'contributors': metadata.contributors
            .map((c) => {
                  'role': c.role.name,
                  'name': {
                    if (c.name.first != null) 'first': c.name.first,
                    if (c.name.middle != null) 'middle': c.name.middle,
                    if (c.name.last != null) 'last': c.name.last,
                    if (c.name.nickname != null) 'nickname': c.name.nickname,
                    if (c.name.display != null) 'display': c.name.display,
                  },
                  if (c.email != null) 'email': c.email,
                  if (c.homePage != null) 'homePage': c.homePage.toString(),
                })
            .toList(),
      if (metadata.series.isNotEmpty)
        'series': metadata.series
            .map((s) => {
                  'name': s.name,
                  if (s.number != null) 'number': s.number,
                  if (s.url != null) 'url': s.url.toString(),
                })
            .toList(),
      if (metadata.publishInfo != null)
        'publishInfo': {
          if (metadata.publishInfo!.publisher != null)
            'publisher': metadata.publishInfo!.publisher,
          if (metadata.publishInfo!.city != null)
            'city': metadata.publishInfo!.city,
          if (metadata.publishInfo!.year != null)
            'year': metadata.publishInfo!.year,
          if (metadata.publishInfo!.isbn != null)
            'isbn': metadata.publishInfo!.isbn,
        },
      if (metadata.srcTitleInfo != null)
        'srcTitleInfo': {
          if (metadata.srcTitleInfo!.title != null)
            'title': metadata.srcTitleInfo!.title,
          if (metadata.srcTitleInfo!.language != null)
            'language': metadata.srcTitleInfo!.language,
          if (metadata.srcTitleInfo!.authors.isNotEmpty)
            'authors': metadata.srcTitleInfo!.authors
                .map((a) => {
                      if (a.name.first != null) 'first': a.name.first,
                      if (a.name.middle != null) 'middle': a.name.middle,
                      if (a.name.last != null) 'last': a.name.last,
                      if (a.name.nickname != null) 'nickname': a.name.nickname,
                      if (a.name.display != null) 'display': a.name.display,
                    })
                .toList(),
        },
      if (metadata.cover != null)
        'cover': {
          'ref': metadata.cover!.ref.id,
          if (metadata.cover!.alt != null) 'alt': metadata.cover!.alt,
        },
    };
  }

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

  /// Сравнивает [Book] с реальным эталонным `.golden.json` файлом на диске.
  static void assertBookMatchesGoldenFile(Book book, String goldenFilePath) {
    final actualJson = bookToJson(book);
    final file = File(goldenFilePath);

    final shouldUpdate = Platform.environment['UPDATE_GOLDENS'] == 'true';
    if (shouldUpdate || !file.existsSync()) {
      file.parent.createSync(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(actualJson));
      if (!shouldUpdate) {
        fail('Golden file was missing and has been created at: $goldenFilePath. Please re-run test.');
      }
      return;
    }

    final expectedJson = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(
      actualJson,
      equals(expectedJson),
      reason: 'AST does not match golden snapshot file: $goldenFilePath',
    );
  }

  /// Сравнивает [BookContent] с реальным эталонным `.golden.json` файлом на диске.
  static void assertContentMatchesGoldenFile(BookContent content, String goldenFilePath) {
    final actualJson = contentToJson(content);
    final file = File(goldenFilePath);

    final shouldUpdate = Platform.environment['UPDATE_GOLDENS'] == 'true';
    if (shouldUpdate || !file.existsSync()) {
      file.parent.createSync(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(actualJson));
      if (!shouldUpdate) {
        fail('Golden file was missing and has been created at: $goldenFilePath. Please re-run test.');
      }
      return;
    }

    final expectedJson = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(
      actualJson,
      equals(expectedJson),
      reason: 'AST does not match golden snapshot file: $goldenFilePath',
    );
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
