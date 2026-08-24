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
/// final blocks = parser.parseFromString('<h1>Заголовок</h1><p>Текст</p>');
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
    dom.NodeList? nodes;
    if (src.contains('<html') ||
        src.contains('<!DOCTYPE') ||
        src.contains('<!doctype') ||
        src.contains('<?xml')) {
      final document = html.parse(src);
      nodes = document.body?.nodes;
    } else {
      final fragment = html.parseFragment(src);
      nodes = fragment.nodes;
    }

    if (nodes == null) return [];
    return parse(nodes);
  }

  static String _fastUnicodeTrim(String text) {
    if (text.isEmpty) return text;
    var start = 0;
    var end = text.length - 1;

    while (start <= end && _isWhitespace(text.codeUnitAt(start))) {
      start++;
    }
    if (start > end) return '';

    while (end >= start && _isWhitespace(text.codeUnitAt(end))) {
      end--;
    }

    return text.substring(start, end + 1);
  }

  static bool _isWhitespace(int codeUnit) {
    return codeUnit <= 0x20 ||
        codeUnit == 0x00A0 ||
        codeUnit == 0x1680 ||
        (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
        codeUnit == 0x202F ||
        codeUnit == 0x205F ||
        codeUnit == 0x3000;
  }

  static final _newlineMatchRegex = RegExp(r'[\r\n\u2028\u2029\u0085]');
  static final _newlineSplitRegex = RegExp(r'[\r\n\u2028\u2029\u0085]+');

  static const _blockTags = {
    'html',
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'section',
    'article',
    'blockquote',
    'ul',
    'ol',
    'pre',
    'figure',
    'hr',
    'table',
    'div',
    'main',
    'body',
    'header',
    'footer',
    'nav',
    'aside',
    'details',
    'summary',
    'address',
    'math',
    'svg',
    'audio',
    'video',
    'img',
    'br',
    'center',
    'font',
  };

  static const _inlineTags = {
    'a',
    'b',
    'strong',
    'i',
    'em',
    'u',
    's',
    'del',
    'strike',
    'code',
    'kbd',
    'samp',
    'sup',
    'sub',
    'span',
    'small',
    'mark',
    'abbr',
    'q',
    'time',
    'var',
    'cite',
    'wbr',
  };

  static bool _isBlockNode(dom.Node node) {
    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
      if (_blockTags.contains(tag)) return true;
      if (_inlineTags.contains(tag)) {
        if (node.children.isEmpty) return false;
        return node.children.any(_isBlockNode);
      }
      return true;
    }
    return false;
  }

  @override
  List<BookBlock> parse(Iterable<dom.Node> nodes) {
    final blocks = <BookBlock>[];
    final inlineBuffer = <dom.Node>[];

    void flushInlines() {
      if (inlineBuffer.isEmpty) return;
      final inlines = _parseInlines(inlineBuffer);
      inlineBuffer.clear();
      blocks.addAll(_inlinesToParagraphBlocks(inlines));
    }

    for (final node in nodes) {
      if (_isBlockNode(node)) {
        flushInlines();
        blocks.addAll(_parseBlockNode(node));
      } else {
        inlineBuffer.add(node);
      }
    }

    flushInlines();
    return blocks;
  }

  static bool _hasLineBreak(BookInline inline) {
    if (inline is BookLineBreak) return true;
    if (inline is BookEmphasis) return inline.children.any(_hasLineBreak);
    if (inline is BookStrong) return inline.children.any(_hasLineBreak);
    if (inline is BookStrike) return inline.children.any(_hasLineBreak);
    if (inline is BookSuperscript) return inline.children.any(_hasLineBreak);
    if (inline is BookSubscript) return inline.children.any(_hasLineBreak);
    if (inline is BookNamedStyle) return inline.inlines.any(_hasLineBreak);
    return false;
  }

  List<BookBlock> _inlinesToParagraphBlocks(List<BookInline> inlines) {
    final hasContent = inlines.any((inline) {
      if (inline is BookText) {
        final clean = _fastUnicodeTrim(inline.text);
        return clean.isNotEmpty;
      }
      if (inline is BookLineBreak) return false;
      return true;
    });
    if (!hasContent) {
      return const <BookBlock>[];
    }
    final hasBreaks = inlines.any(_hasLineBreak);
    if (!hasBreaks) {
      return [BookParagraph(inlines: inlines)];
    }
    final chunks = _splitInlinesByLineBreaks(inlines);
    if (chunks.isEmpty) return const <BookBlock>[];
    final result = <BookBlock>[];
    for (final chunk in chunks) {
      if (chunk.isEmpty) {
        result.add(const BookEmptyLine());
      } else {
        final hasText =
            chunk.any((i) => i is! BookText || i.text.trim().isNotEmpty);
        if (hasText) {
          result.add(BookParagraph(inlines: chunk));
        }
      }
    }
    return result;
  }

  List<BookBlock> _parseBlockNode(dom.Node node) {
    if (node is! dom.Element) {
      return const [];
    }

    final tag = node.localName?.toLowerCase();
    return switch (tag) {
      'section' || 'article' => [_parseSection(node)],
      'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => [_parseHeading(node)],
      'p' => () {
        final inlines = _parseInlines(node.nodes);
        final hasContent = inlines.any((inline) {
          if (inline is BookText) return inline.text.trim().isNotEmpty;
          if (inline is BookLineBreak) return false;
          return true;
        });
        if (!hasContent) {
          return inlines.any((inline) => inline is BookLineBreak)
              ? const <BookBlock>[BookEmptyLine()]
              : const <BookBlock>[];
        }
        return _inlinesToParagraphBlocks(inlines);
      }(),
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
      'div' ||
      'main' ||
      'body' ||
      'header' ||
      'footer' ||
      'nav' ||
      'aside' ||
      'details' ||
      'summary' ||
      'address' ||
      'center' ||
      'font' ||
      'span' =>
        node.classes.contains('poem') ? [_parsePoem(node)] : parse(node.nodes),
      'strong' ||
      'b' ||
      'em' ||
      'i' ||
      'u' ||
      's' ||
      'del' ||
      'strike' ||
      'a' =>
        _wrapBlocksWithInline(parse(node.nodes), tag),
      _ => () {
        if (strictMode) {
          throw BookParseException('Unhandled HTML element <$tag>', tag: tag);
        }
        logger?.call(
          'Warning: unhandled HTML element <$tag>, fallback to BookRawHtmlBlock',
        );
        return <BookBlock>[BookRawHtmlBlock(node.outerHtml)];
      }(),
    };
  }

  List<BookBlock> _wrapBlocksWithInline(List<BookBlock> blocks, String? tag) {
    if (tag == null || tag == 'a') return blocks;
    return blocks.map((block) {
      if (block is BookParagraph) {
        final wrapped = switch (tag) {
          'strong' || 'b' => BookStrong(children: block.inlines),
          'em' || 'i' || 'u' => BookEmphasis(children: block.inlines),
          's' || 'del' || 'strike' => BookStrike(children: block.inlines),
          _ => null,
        };
        if (wrapped != null) {
          return BookParagraph(inlines: [wrapped]);
        }
      }
      return block;
    }).toList();
  }

  BookCodeBlock _parseCodeBlock(dom.Element node) {
    final codeElem = node.querySelector('code') ?? node;
    String? lang =
        codeElem.attributes['data-language'] ??
        node.attributes['data-language'] ??
        codeElem.attributes['lang'] ??
        node.attributes['lang'];

    if (lang == null) {
      for (final cls in [...codeElem.classes, ...node.classes]) {
        if (cls.startsWith('language-') && cls.length > 'language-'.length) {
          lang = cls.substring('language-'.length);
          break;
        }
      }
    }
    if (lang == null) {
      final classAttr =
          codeElem.attributes['class'] ?? node.attributes['class'];
      if (classAttr != null && classAttr.isNotEmpty) {
        lang = classAttr.split(' ').first;
      }
    }

    return BookCodeBlock(code: node.text, language: lang);
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

  BookQuote _parseQuote(dom.Element element) {
    final citationElem = element.querySelector('.citation, cite, footer');
    final citation = citationElem != null
        ? _parseInlines(citationElem.nodes)
        : const <BookInline>[];

    final blockNodes = <dom.Node>[];
    for (final node in element.nodes) {
      if (identical(node, citationElem)) continue;
      if (citationElem != null && citationElem.contains(node)) continue;
      blockNodes.add(node);
    }

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
    final src =
        element.attributes['src'] ??
        element.querySelector('source')?.attributes['src'] ??
        '';
    final id = registrar?.call(src, isInline: false) ?? src;
    return BookAudioBlock(
      ref: BookResourceRef(id),
      controls: element.attributes.containsKey('controls'),
    );
  }

  BookVideoBlock _parseVideoBlock(dom.Element element) {
    final src =
        element.attributes['src'] ??
        element.querySelector('source')?.attributes['src'] ??
        '';
    final poster = element.attributes['poster'];
    final id = registrar?.call(src, isInline: false) ?? src;
    final posterId = poster != null
        ? registrar?.call(poster, isInline: false) ?? poster
        : null;
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
      if (identical(child, titleNode) ||
          (titleNode != null && titleNode.contains(child))) {
        continue;
      }

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

      final blocks = <BookBlock>[];
      final currentInlines = <dom.Node>[];

      void flushInlines() {
        if (currentInlines.isNotEmpty) {
          final inlines = _parseInlines(currentInlines);
          final hasVisible = inlines.any(
            (i) =>
                (i is BookText && i.text.trim().isNotEmpty) ||
                (i is! BookText && i is! BookLineBreak),
          );
          if (hasVisible) {
            blocks.addAll(_inlinesToParagraphBlocks(inlines));
          }
          currentInlines.clear();
        }
      }

      for (final node in child.nodes) {
        if (node is dom.Element &&
            const {
              'p',
              'div',
              'ul',
              'ol',
              'blockquote',
              'table',
              'pre',
              'section',
              'article',
              'h1',
              'h2',
              'h3',
              'h4',
              'h5',
              'h6',
              'figure',
              'hr',
              'audio',
              'video',
              'math',
              'svg',
            }.contains((node.localName ?? '').toLowerCase())) {
          flushInlines();
          blocks.addAll(_parseBlockNode(node));
        } else {
          currentInlines.add(node);
        }
      }
      flushInlines();

      if (blocks.isEmpty) {
        blocks.add(BookParagraph(inlines: _parseInlines(child.nodes)));
      }

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
        var align = cell.attributes['align'];
        var vAlign = cell.attributes['valign'];
        final style = cell.attributes['style'] ?? '';
        if (align == null && style.contains('text-align:')) {
          final match = RegExp(
            r'text-align\s*:\s*([a-zA-Z]+)',
          ).firstMatch(style);
          align = match?.group(1);
        }
        if (vAlign == null && style.contains('vertical-align:')) {
          final match = RegExp(
            r'vertical-align\s*:\s*([a-zA-Z]+)',
          ).firstMatch(style);
          vAlign = match?.group(1);
        }

        final blocks = parse(cell.nodes);
        cells.add(
          BookTableCell(
            blocks: blocks.isEmpty
                ? [BookParagraph(inlines: _parseInlines(cell.nodes))]
                : blocks,
            colSpan: colSpan,
            rowSpan: rowSpan,
            align: align,
            vAlign: vAlign,
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
    final elemId = element.attributes['id'];
    final id = registrar?.call(src, isInline: false) ?? src;

    final attributes = <String, String>{};
    if (src.isNotEmpty) {
      attributes['source-src'] = src;
    }

    return BookImageBlock(
      id: elemId,
      ref: BookResourceRef(id),
      alt: alt,
      title: title,
      attributes: attributes,
    );
  }

  List<BookInline> _parseInlines(Iterable<dom.Node> nodes) {
    final inlines = <BookInline>[];
    for (final node in nodes) {
      _collectInlineNode(node, inlines);
    }
    return inlines;
  }

  void _collectInlineNode(dom.Node node, List<BookInline> target) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) return;
      final hasNewline = _newlineMatchRegex.hasMatch(text);
      if (hasNewline) {
        final parts = text.split(_newlineSplitRegex);
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          final trimmedPart = _fastUnicodeTrim(part);
          if (trimmedPart.isNotEmpty) {
            target.add(BookText(trimmedPart));
          }
          if (i < parts.length - 1) {
            target.add(const BookLineBreak());
          }
        }
        return;
      }
      if (text.trim().isEmpty) {
        target.add(const BookText(' '));
        return;
      }
      target.add(BookText(text));
      return;
    }

    if (node is! dom.Element) {
      return;
    }

    final tag = node.localName?.toLowerCase();
    final id = node.attributes['id'] ?? node.attributes['name'];

    if (id != null && id.isNotEmpty && tag != 'a' && tag != 'img') {
      target.add(BookAnchor(id));
    }

    switch (tag) {
      case 'br':
        target.add(const BookLineBreak());
      case 'strong' || 'b':
        target.add(BookStrong(children: _parseInlines(node.nodes)));
      case 'em' || 'i' || 'u' || 'cite' || 'var':
        target.add(BookEmphasis(children: _parseInlines(node.nodes)));
      case 's' || 'del' || 'strike':
        target.add(BookStrike(children: _parseInlines(node.nodes)));
      case 'code' || 'kbd' || 'samp':
        target.add(BookCodeSpan(node.text));
      case 'sup':
        target.add(BookSuperscript(children: _parseInlines(node.nodes)));
      case 'sub':
        target.add(BookSubscript(children: _parseInlines(node.nodes)));
      case 'a':
        target.addAll(_parseLink(node));
      case 'img':
        target.addAll(_parseInlineImage(node));
      case 'span':
        _collectSpan(node, target);
      case 'small' ||
            'mark' ||
            'abbr' ||
            'q' ||
            'time' ||
            'font' ||
            'center' ||
            'div' ||
            'main' ||
            'body' ||
            'header' ||
            'footer' ||
            'nav' ||
            'aside' ||
            'details' ||
            'summary' ||
            'address' ||
            'p' ||
            'h1' ||
            'h2' ||
            'h3' ||
            'h4' ||
            'h5' ||
            'h6' ||
            'section' ||
            'article' ||
            'blockquote':
        for (final child in node.nodes) {
          _collectInlineNode(child, target);
        }
      default:
        target.addAll(_handleUnhandledInline(node, tag));
    }
  }

  void _collectSpan(dom.Element node, List<BookInline> target) {
    final classAttr = node.attributes['class'];
    if (classAttr != null && classAttr.contains('style-')) {
      for (final cls in node.classes) {
        if (cls.startsWith('style-') && cls.length > 'style-'.length) {
          final styleName = cls.substring('style-'.length);
          target.add(
            BookNamedStyle(name: styleName, inlines: _parseInlines(node.nodes)),
          );
          return;
        }
      }
    }
    for (final child in node.nodes) {
      _collectInlineNode(child, target);
    }
  }

  List<BookInline> _handleUnhandledInline(dom.Element node, String? tag) {
    if (strictMode) {
      throw BookParseException(
        'Unhandled HTML inline element <$tag>',
        tag: tag,
      );
    }
    logger?.call(
      'Warning: unhandled HTML inline element <$tag>, fallback to BookRawHtmlInline',
    );
    return [BookRawHtmlInline(node.outerHtml)];
  }

  List<BookInline> _parseInlineImage(dom.Element node) {
    final src = (node.attributes['src'] ?? '').trim();
    final alt = node.attributes['alt'];
    final title = node.attributes['title'];
    final elemId = node.attributes['id'];
    final id = registrar?.call(src, isInline: true) ?? src;
    return [
      BookImageInline(
        id: elemId,
        ref: BookResourceRef(id),
        alt: alt,
        title: title,
        attributes: src.isEmpty ? const {} : {'source-src': src},
      ),
    ];
  }

  List<BookInline> _parseLink(dom.Element node) {
    final href = (node.attributes['href'] ?? '').trim();
    final children = _parseInlines(node.nodes);
    final id = node.attributes['id'] ?? node.attributes['name'];
    final epubType =
        node.attributes['epub:type'] ?? node.attributes['role'] ?? '';

    if (epubType.contains('noteref') || epubType.contains('doc-noteref')) {
      final noteId = href.startsWith('#') ? href.substring(1) : href;
      final fnRef = BookFootnoteRef(
        id: noteId.isNotEmpty ? noteId : (id ?? ''),
        label: children,
      );
      if (id != null && id.isNotEmpty) {
        return [BookAnchor(id), fnRef];
      }
      return [fnRef];
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

  List<List<BookInline>> _splitInlinesByLineBreaks(List<BookInline> inlines) {
    var chunks = <List<BookInline>>[[]];
    var lastWasLineBreak = false;

    for (final inline in inlines) {
      if (inline is BookLineBreak) {
        if (!lastWasLineBreak) {
          chunks.add([]);
          lastWasLineBreak = true;
        }
      } else {
        lastWasLineBreak = false;
        final splitResults = _splitSingleInline(inline);
        for (var i = 0; i < splitResults.length; i++) {
          final subInline = splitResults[i];
          if (subInline != null) {
            chunks.last.add(subInline);
          }
          if (i < splitResults.length - 1) {
            chunks.add([]);
          }
        }
      }
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  List<BookInline?> _splitSingleInline(BookInline inline) {
    if (!_hasLineBreak(inline)) {
      return [inline];
    }
    return switch (inline) {
      BookStrong s => _wrapSplitChildren(
          s.children,
          (c) => BookStrong(children: c, attributes: s.attributes),
        ),
      BookEmphasis e => _wrapSplitChildren(
          e.children,
          (c) => BookEmphasis(children: c, attributes: e.attributes),
        ),
      BookStrike st => _wrapSplitChildren(
          st.children,
          (c) => BookStrike(children: c, attributes: st.attributes),
        ),
      BookNamedStyle ns => _wrapSplitChildren(
          ns.inlines,
          (c) => BookNamedStyle(
            name: ns.name,
            inlines: c,
            attributes: ns.attributes,
          ),
        ),
      BookLink l => _wrapSplitChildren(
          l.children,
          (c) => BookLink(href: l.href, children: c, attributes: l.attributes),
        ),
      BookSuperscript sup => _wrapSplitChildren(
          sup.children,
          (c) =>
              BookSuperscript(children: c, attributes: sup.attributes),
        ),
      BookSubscript sub => _wrapSplitChildren(
          sub.children,
          (c) => BookSubscript(children: c, attributes: sub.attributes),
        ),
      _ => [inline],
    };
  }

  List<BookInline?> _wrapSplitChildren(
    List<BookInline> children,
    BookInline Function(List<BookInline>) wrapper,
  ) {
    final subChunks = _splitInlinesByLineBreaks(children);
    if (subChunks.isEmpty) return [null];
    return subChunks
        .map<BookInline?>((chunk) => chunk.isNotEmpty ? wrapper(chunk) : null)
        .toList();
  }
}
