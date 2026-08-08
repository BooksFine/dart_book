import 'package:dart_book/src/models/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import '../models/book.dart';

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
  HtmlParser({this.registrar});

  @override
  final BookResourceRegistrar? registrar;

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
      'blockquote' => [BookQuote(blocks: parse(node.nodes))],
      'ul' || 'ol' => [_parseList(node, ordered: tag == 'ol')],
      'pre' => [
        BookCodeBlock(
          code: node.text,
          language:
              node.attributes['data-language'] ??
              node.attributes['lang'] ??
              node.attributes['class'],
        ),
      ],
      'hr' => const [BookHorizontalRule()],
      'img' => [_parseImageBlock(node)],
      'table' => [_parseTable(node)],
      'br' => const [BookEmptyLine()],
      'div' || 'main' || 'body' => parse(node.nodes),
      _ => [BookRawHtmlBlock(node.outerHtml)],
    };
  }

  BookSection _parseSection(dom.Element element) {
    final titleNode = element.children.firstWhere(
      (child) => RegExp(r'h[1-6]').hasMatch(child.localName ?? ''),
      orElse: () => dom.Element.tag(''),
    );

    final title = titleNode.localName == null || titleNode.localName!.isEmpty
        ? const <BookInline>[]
        : _parseInlines(titleNode.nodes);

    final contentNodes = <dom.Node>[];
    for (final child in element.nodes) {
      if (identical(child, titleNode)) continue;
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
          ? parse(child.nodes)
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
    return switch (tag) {
      'br' => const [BookLineBreak()],
      'strong' || 'b' => [BookStrong(children: _parseInlines(node.nodes))],
      'em' || 'i' || 'u' => [BookEmphasis(children: _parseInlines(node.nodes))],
      's' ||
      'del' ||
      'strike' => [BookStrike(children: _parseInlines(node.nodes))],
      'code' => [BookCodeSpan(node.text)],
      'sup' => [BookSuperscript(children: _parseInlines(node.nodes))],
      'sub' => [BookSubscript(children: _parseInlines(node.nodes))],
      'a' => _parseLink(node),
      'img' => _parseInlineImage(node),
      'span' || 'small' || 'mark' || 'abbr' => _parseInlines(node.nodes),
      _ => [BookRawHtmlInline(node.outerHtml)],
    };
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
    final uri = Uri.tryParse(href);
    if (uri != null && href.isNotEmpty) {
      return [BookLink(href: uri, children: children)];
    }
    return [BookRawHtmlInline(node.outerHtml)];
  }
}
