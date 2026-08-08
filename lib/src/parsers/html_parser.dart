import 'package:dart_book/src/models/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import '../models/book.dart';
import '../models/exceptions.dart';

/// Парсер HTML-контента в дерево [BookBlock].
///
/// Использует пакет `html` для разбора HTML. Поддерживает
/// полный набор HTML5-элементов: заголовки, абзацы, цитаты,
/// списки, таблицы, блоки кода, секции и изображения.
///
/// Пример:
/// ```dart
/// final parser = HtmlParser(
///   registrar: (src, {required isInline}) => Uri.parse(src).pathSegments.last,
/// );
/// final blocks = parser.parseFragment('<h1>Заголовок</h1><p>Текст</p>');
/// ```
class HtmlParser implements Parser<Iterable<dom.Node>> {
  HtmlParser({
    this.registrar,
    this.strictMode = false,
    this.logger,
  });

  @override
  final BookResourceRegistrar? registrar;

  final bool strictMode;
  final void Function(String warning)? logger;

  @override
  List<BookBlock> parseFromString(String src) {
    final document = html.parse(src);
    final nodes = document.body?.nodes;
    if (nodes == null) return [];

    return parse(nodes);
  }

  @override
  List<BookBlock> parse(Iterable<dom.Node> nodes) {
    final blocks = <BookBlock>[];
    for (final node in nodes) {
      blocks.addAll(_parseBlockNode(node));
    }
    return blocks;
  }

  List<BookBlock> _parseBlockNode(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return const [];
      return [
        BookParagraph(inlines: [BookText(text)]),
      ];
    }

    if (node is! dom.Element) {
      return const [];
    }

    final tag = node.localName?.toLowerCase();
    return switch (tag) {
      'section' || 'article' => [_parseSection(node)],
      'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => [_parseHeading(node)],
      'p' => [BookParagraph(inlines: _parseInlines(node.nodes))],
      'blockquote' => [_parseQuote(node)],
      'ul' || 'ol' => [_parseList(node, ordered: tag == 'ol')],
      'pre' => [_parseCodeBlock(node)],
      'figure' => [_parseFigure(node)],
      'hr' => const [BookHorizontalRule()],
      'img' => [_parseImageBlock(node)],
      'audio' => [_parseAudioBlock(node)],
      'video' => [_parseVideoBlock(node)],
      'math' => [BookMathBlock(mathml: node.outerHtml)],
      'svg' => [BookSvgBlock(svg: node.outerHtml)],
      'table' => [_parseTable(node)],
      'br' => const [BookEmptyLine()],
      'div' || 'main' || 'body' || 'header' || 'footer' || 'nav' || 'aside' || 'details' || 'summary' || 'address' =>
        node.classes.contains('poem') ? [_parsePoem(node)] : parse(node.nodes),
      _ => _handleUnhandledElement(node, tag),
    };
  }

  BookCodeBlock _parseCodeBlock(dom.Element node) {
    final codeElem = node.querySelector('code') ?? node;
    final lang = codeElem.attributes['data-language'] ??
        codeElem.attributes['lang'] ??
        codeElem.attributes['class'] ??
        node.attributes['data-language'] ??
        node.attributes['lang'] ??
        node.attributes['class'];

    var languageClean = lang;
    if (languageClean != null && languageClean.contains('language-')) {
      languageClean = languageClean.split('language-').last.split(' ').first;
    }

    return BookCodeBlock(
      code: node.text,
      language: languageClean,
    );
  }

  BookBlock _parseFigure(dom.Element element) {
    final imgElem = element.querySelector('img');
    final captionElem = element.querySelector('figcaption');
    final captionText = captionElem?.text.trim();

    if (imgElem != null) {
      final src = (imgElem.attributes['src'] ?? '').trim();
      final alt = captionText ?? imgElem.attributes['alt'];
      final id = registrar?.call(src, isInline: false) ?? src;
      return BookImageBlock(
        ref: BookResourceRef(id),
        alt: alt,
        title: imgElem.attributes['title'],
      );
    }

    return BookParagraph(inlines: _parseInlines(element.nodes));
  }

  List<BookBlock> _handleUnhandledElement(dom.Element node, String? tag) {
    if (strictMode) {
      throw BookParseException('Unhandled HTML element <$tag>', tag: tag);
    }
    logger?.call('Warning: unhandled HTML element <$tag>, fallback to BookRawHtmlBlock');
    return [BookRawHtmlBlock(node.outerHtml)];
  }

  BookQuote _parseQuote(dom.Element element) {
    final citationElem = element.querySelector('.citation, cite, footer');
    final citation = citationElem != null ? _parseInlines(citationElem.nodes) : const <BookInline>[];

    final blockNodes = element.nodes.where(
      (n) => !identical(n, citationElem) && (citationElem == null || !citationElem.contains(n)),
    );

    return BookQuote(blocks: parse(blockNodes), citation: citation);
  }

  BookPoem _parsePoem(dom.Element element) {
    final stanzas = <BookStanza>[];
    final stanzaElems = element.querySelectorAll('.stanza');
    final targets = stanzaElems.isNotEmpty ? stanzaElems : [element];

    for (final stanzaElem in targets) {
      final lines = <BookPoemLine>[];
      for (final p in stanzaElem.querySelectorAll('.poem-line, p')) {
        lines.add(BookPoemLine(inlines: _parseInlines(p.nodes)));
      }
      if (lines.isNotEmpty) {
        stanzas.add(BookStanza(lines: lines));
      }
    }

    return BookPoem(stanzas: stanzas);
  }

  BookAudioBlock _parseAudioBlock(dom.Element element) {
    final src = element.attributes['src'] ??
        element.querySelector('source')?.attributes['src'] ??
        '';
    final id = registrar?.call(src, isInline: false) ?? src;
    return BookAudioBlock(
      ref: BookResourceRef(id),
      controls: element.attributes.containsKey('controls'),
    );
  }

  BookVideoBlock _parseVideoBlock(dom.Element element) {
    final src = element.attributes['src'] ??
        element.querySelector('source')?.attributes['src'] ??
        '';
    final poster = element.attributes['poster'];
    final id = registrar?.call(src, isInline: false) ?? src;
    final posterId = poster != null ? registrar?.call(poster, isInline: false) ?? poster : null;
    return BookVideoBlock(
      ref: BookResourceRef(id),
      posterRef: posterId != null ? BookResourceRef(posterId) : null,
      controls: element.attributes.containsKey('controls'),
    );
  }

  BookSection _parseSection(dom.Element element) {
    final titleNode = element.querySelector('h1, h2, h3, h4, h5, h6');

    final title = titleNode == null
        ? const <BookInline>[]
        : _parseInlines(titleNode.nodes);

    final contentNodes = <dom.Node>[];
    for (final child in element.nodes) {
      if (identical(child, titleNode) || (titleNode != null && titleNode.contains(child))) continue;
      contentNodes.add(child);
    }

    final attributes = <String, String>{};
    final id = element.attributes['id'];
    if (id != null && id.isNotEmpty) {
      attributes['source-id'] = id;
    }

    return BookSection(
      id: id,
      title: title,
      blocks: parse(contentNodes),
      attributes: attributes,
    );
  }

  BookHeading _parseHeading(dom.Element element) {
    final level = int.tryParse((element.localName ?? 'h1').replaceAll('h', ''));
    return BookHeading(
      level: level == null || level < 1 ? 1 : level,
      text: _parseInlines(element.nodes),
    );
  }

  BookList _parseList(dom.Element element, {required bool ordered}) {
    final items = <BookListItem>[];
    for (final child in element.children) {
      if ((child.localName ?? '').toLowerCase() != 'li') continue;

      final hasBlockChild = child.children.any(
        (c) => const {
          'p',
          'div',
          'ul',
          'ol',
          'blockquote',
          'table',
          'pre',
          'section',
          'article',
        }.contains((c.localName ?? '').toLowerCase()),
      );

      final blocks = hasBlockChild
          ? parse(child.children)
          : <BookBlock>[BookParagraph(inlines: _parseInlines(child.nodes))];
      items.add(BookListItem(blocks: blocks));
    }
    return BookList(ordered: ordered, items: items);
  }

  BookTable _parseTable(dom.Element element) {
    final rows = <BookTableRow>[];
    final trElements = element.querySelectorAll('tr');
    for (final tr in trElements) {
      final cells = <BookTableCell>[];
      for (final cell in tr.children.where(
        (c) =>
            (c.localName ?? '').toLowerCase() == 'td' ||
            (c.localName ?? '').toLowerCase() == 'th',
      )) {
        final colSpan = int.tryParse(cell.attributes['colspan'] ?? '');
        final rowSpan = int.tryParse(cell.attributes['rowspan'] ?? '');

        final blocks = parse(cell.nodes);
        cells.add(
          BookTableCell(
            blocks: blocks.isEmpty
                ? [BookParagraph(inlines: _parseInlines(cell.nodes))]
                : blocks,
            colSpan: colSpan,
            rowSpan: rowSpan,
          ),
        );
      }
      rows.add(BookTableRow(cells: cells));
    }
    return BookTable(rows: rows);
  }

  BookImageBlock _parseImageBlock(dom.Element element) {
    final src = (element.attributes['src'] ?? '').trim();
    final alt = element.attributes['alt'];
    final title = element.attributes['title'];
    final id = registrar?.call(src, isInline: false) ?? src;

    final attributes = <String, String>{};
    if (src.isNotEmpty) {
      attributes['source-src'] = src;
    }

    return BookImageBlock(
      ref: BookResourceRef(id),
      alt: alt,
      title: title,
      attributes: attributes,
    );
  }

  List<BookInline> _parseInlines(List<dom.Node> nodes) {
    final inlines = <BookInline>[];
    for (final node in nodes) {
      inlines.addAll(_parseInlineNode(node));
    }
    return inlines;
  }

  List<BookInline> _parseInlineNode(dom.Node node) {
    if (node is dom.Text) {
      if (node.text.isEmpty) return const [];
      return [BookText(node.text)];
    }

    if (node is! dom.Element) {
      return const [];
    }

    final tag = node.localName?.toLowerCase();
    final id = node.attributes['id'] ?? node.attributes['name'];
    final inlines = <BookInline>[];

    if (id != null && id.isNotEmpty && tag != 'a') {
      inlines.add(BookAnchor(id));
    }

    final parsedInlines = switch (tag) {
      'br' => const [BookLineBreak()],
      'strong' || 'b' => [BookStrong(children: _parseInlines(node.nodes))],
      'em' || 'i' || 'u' || 'cite' || 'var' => [BookEmphasis(children: _parseInlines(node.nodes))],
      's' || 'del' || 'strike' => [BookStrike(children: _parseInlines(node.nodes))],
      'code' || 'kbd' || 'samp' => [BookCodeSpan(node.text)],
      'sup' => [BookSuperscript(children: _parseInlines(node.nodes))],
      'sub' => [BookSubscript(children: _parseInlines(node.nodes))],
      'a' => _parseLink(node),
      'img' => _parseInlineImage(node),
      'span' || 'small' || 'mark' || 'abbr' || 'q' || 'time' => _parseInlines(node.nodes),
      _ => _handleUnhandledInline(node, tag),
    };

    inlines.addAll(parsedInlines);
    return inlines;
  }

  List<BookInline> _handleUnhandledInline(dom.Element node, String? tag) {
    if (strictMode) {
      throw BookParseException('Unhandled HTML inline element <$tag>', tag: tag);
    }
    logger?.call('Warning: unhandled HTML inline element <$tag>, fallback to BookRawHtmlInline');
    return [BookRawHtmlInline(node.outerHtml)];
  }

  List<BookInline> _parseInlineImage(dom.Element node) {
    final src = (node.attributes['src'] ?? '').trim();
    final id = registrar?.call(src, isInline: true) ?? src;
    return [
      BookImageInline(
        ref: BookResourceRef(id),
        alt: node.attributes['alt'],
        attributes: src.isEmpty ? const {} : {'source-src': src},
      ),
    ];
  }

  List<BookInline> _parseLink(dom.Element node) {
    final href = (node.attributes['href'] ?? '').trim();
    final children = _parseInlines(node.nodes);
    final id = node.attributes['id'] ?? node.attributes['name'];
    final epubType = node.attributes['epub:type'] ?? node.attributes['role'] ?? '';

    if (epubType.contains('noteref') || epubType.contains('doc-noteref')) {
      final noteId = href.startsWith('#') ? href.substring(1) : href;
      return [BookFootnoteRef(id: noteId.isNotEmpty ? noteId : (id ?? ''), label: children)];
    }

    if (href.isEmpty) {
      if (id != null && id.isNotEmpty) {
        return [BookAnchor(id), ...children];
      }
      return children;
    }

    final uri = Uri.tryParse(href);
    if (uri != null) {
      final link = BookLink(href: uri, children: children);
      if (id != null && id.isNotEmpty) {
        return [BookAnchor(id), link];
      }
      return [link];
    }

    return children;
  }
}
