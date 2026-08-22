import 'package:xml/xml.dart';
import '../models/book.dart';
import '../models/exceptions.dart';
import '../models/parser.dart';

/// Парсер контента для формата FictionBook 2 (FB2).
/// Реализует интерфейс [Parser] для преобразования XML-фрагментов в блоки книги.
class Fb2Parser implements Parser<Iterable<XmlNode>> {
  @override
  final BookResourceRegistrar? registrar;

  final bool strictMode;
  final void Function(String warning)? logger;

  Fb2Parser({this.registrar, this.strictMode = false, this.logger});

  @override
  List<BookBlock> parseFromString(String text) {
    final document = XmlDocument.parse(text);
    final root = document.rootElement;

    // Если передан весь документ, ищем body, иначе парсим текущий элемент
    if (root.localName == 'FictionBook') {
      final blocks = <BookBlock>[];
      for (final body in root.findElements('body')) {
        if (body.getAttribute('name') == 'notes') continue;
        blocks.addAll(parse(body.children));
      }
      return blocks;
    }

    return parse([root]);
  }

  /// Парсит список XML-узлов в блоки книги.
  @override
  List<BookBlock> parse(Iterable<XmlNode> nodes) {
    final blocks = <BookBlock>[];
    for (final node in nodes) {
      if (node is XmlElement) {
        blocks.addAll(_parseFb2Element(node));
      } else if (node is XmlText) {
        final text = node.value.trim();
        if (text.isNotEmpty) {
          blocks.add(BookParagraph(inlines: [BookText(text)]));
        }
      }
    }
    return blocks;
  }

  List<BookBlock> _parseFb2Element(XmlElement element) {
    final name = element.localName.toLowerCase();
    switch (name) {
      case 'section':
        final titleElement = element.findElements('title').firstOrNull;
        final title = titleElement != null
            ? _parseFb2Title(titleElement)
            : <BookInline>[];

        final innerBlocks = parse(
          element.children.where(
            (e) => e is! XmlElement || e.localName != 'title',
          ),
        );

        return [
          BookSection(
            id: element.getAttribute('id'),
            title: title,
            blocks: innerBlocks,
          ),
        ];
      case 'p':
        return [BookParagraph(inlines: _parseFb2Inlines(element))];
      case 'title':
        return [BookHeading(level: 1, text: _parseFb2Title(element))];
      case 'subtitle':
        final paragraphs = element.findElements('p').toList();
        if (paragraphs.isNotEmpty) {
          final inlines = <BookInline>[];
          for (var i = 0; i < paragraphs.length; i++) {
            if (i > 0) inlines.add(const BookLineBreak());
            inlines.addAll(_parseFb2Inlines(paragraphs[i]));
          }
          return [BookHeading(level: 2, text: inlines)];
        }
        return [BookHeading(level: 2, text: _parseFb2Inlines(element))];
      case 'empty-line':
        return [const BookEmptyLine()];
      case 'image':
        final href =
            element.getAttribute('l:href') ??
            element.getAttribute('href') ??
            '';
        final imgId = element.getAttribute('id');
        final alt = element.getAttribute('alt');
        final title = element.getAttribute('title');
        final id =
            registrar?.call(href, isInline: false) ??
            (href.startsWith('#') ? href.substring(1) : href);
        return [
          BookImageBlock(
            id: imgId,
            ref: BookResourceRef(id),
            alt: alt,
            title: title,
          ),
        ];
      case 'cite':
        final textAuthors = element.findElements('text-author').toList();
        final citation = <BookInline>[];
        for (var i = 0; i < textAuthors.length; i++) {
          if (i > 0) citation.add(const BookText(', '));
          citation.addAll(_parseFb2Inlines(textAuthors[i]));
        }
        final innerBlocks = parse(
          element.children.where(
            (e) => e is! XmlElement || e.localName != 'text-author',
          ),
        );
        return [BookQuote(blocks: innerBlocks, citation: citation)];
      case 'poem':
        final stanzas = <BookStanza>[];
        for (final stanzaElem in element.findElements('stanza')) {
          final lines = <BookPoemLine>[];
          for (final v in stanzaElem.findElements('v')) {
            lines.add(BookPoemLine(inlines: _parseFb2Inlines(v)));
          }
          stanzas.add(BookStanza(lines: lines));
        }
        return [BookPoem(stanzas: stanzas)];
      case 'table':
        final rows = <BookTableRow>[];
        for (final tr in element.findElements('tr')) {
          final cells = <BookTableCell>[];
          for (final cell in tr.children.whereType<XmlElement>().where(
            (e) => e.localName == 'td' || e.localName == 'th',
          )) {
            final colSpan =
                int.tryParse(cell.getAttribute('colspan') ?? '') ?? 1;
            final rowSpan =
                int.tryParse(cell.getAttribute('rowspan') ?? '') ?? 1;
            final align = cell.getAttribute('align');
            final vAlign = cell.getAttribute('valign');
            final pElements = cell.findElements('p').toList();
            final cellBlocks = pElements.isNotEmpty
                ? pElements
                      .map((p) => BookParagraph(inlines: _parseFb2Inlines(p)))
                      .toList()
                : [BookParagraph(inlines: _parseFb2Inlines(cell))];
            cells.add(
              BookTableCell(
                blocks: cellBlocks,
                colSpan: colSpan > 1 ? colSpan : null,
                rowSpan: rowSpan > 1 ? rowSpan : null,
                align: align,
                vAlign: vAlign,
              ),
            );
          }
          rows.add(BookTableRow(cells: cells));
        }
        return [BookTable(rows: rows)];
      case 'epigraph':
        final textAuthors = element.findElements('text-author').toList();
        final citation = <BookInline>[];
        for (var i = 0; i < textAuthors.length; i++) {
          if (i > 0) citation.add(const BookText(', '));
          citation.addAll(_parseFb2Inlines(textAuthors[i]));
        }
        final innerBlocks = parse(
          element.children.where(
            (e) => e is! XmlElement || e.localName != 'text-author',
          ),
        );
        return [
          BookQuote(
            blocks: innerBlocks,
            citation: citation,
            attributes: const {'fb2-type': 'epigraph'},
          ),
        ];
      case 'code' || 'pre':
        return [BookCodeBlock(code: element.innerText)];
      case 'body':
        return parse(element.children);
      default:
        if (strictMode) {
          throw BookParseException('Unhandled FB2 element <$name>', tag: name);
        }
        logger?.call(
          'Warning: unhandled FB2 element <$name>, parsing children',
        );
        return parse(element.children);
    }
  }

  List<BookInline> _parseFb2Inlines(XmlNode node) {
    final inlines = <BookInline>[];
    for (final child in node.children) {
      if (child is XmlText) {
        inlines.add(BookText(child.value));
      } else if (child is XmlElement) {
        final name = child.localName.toLowerCase();
        switch (name) {
          case 'strong':
            inlines.add(BookStrong(children: _parseFb2Inlines(child)));
          case 'emphasis':
            inlines.add(BookEmphasis(children: _parseFb2Inlines(child)));
          case 'sub':
            inlines.add(BookSubscript(children: _parseFb2Inlines(child)));
          case 'sup':
            inlines.add(BookSuperscript(children: _parseFb2Inlines(child)));
          case 'strikethrough' || 'strike':
            inlines.add(BookStrike(children: _parseFb2Inlines(child)));
          case 'code':
            inlines.add(BookCodeSpan(child.innerText));
          case 'style':
            final styleName = child.getAttribute('name') ?? '';
            final innerInlines = _parseFb2Inlines(child);
            if (styleName.isNotEmpty) {
              inlines.add(
                BookNamedStyle(name: styleName, inlines: innerInlines),
              );
            } else {
              inlines.addAll(innerInlines);
            }
          case 'empty-line':
            inlines.add(const BookLineBreak());
          case 'a':
            final href =
                child.getAttribute('l:href') ??
                child.getAttribute('href') ??
                '';
            final type = child.getAttribute('type');
            if (type == 'note' ||
                href.startsWith('#n_') ||
                href.startsWith('#note')) {
              final id = href.startsWith('#') ? href.substring(1) : href;
              inlines.add(
                BookFootnoteRef(id: id, label: _parseFb2Inlines(child)),
              );
            } else {
              final uri = Uri.tryParse(href) ?? Uri();
              inlines.add(
                BookLink(
                  href: uri,
                  children: _parseFb2Inlines(child),
                ),
              );
            }
          case 'image':
            final href =
                child.getAttribute('l:href') ??
                child.getAttribute('href') ??
                '';
            final imgId = child.getAttribute('id');
            final alt = child.getAttribute('alt');
            final title = child.getAttribute('title');
            final id =
                registrar?.call(href, isInline: true) ??
                (href.startsWith('#') ? href.substring(1) : href);
            inlines.add(
              BookImageInline(
                id: imgId,
                ref: BookResourceRef(id),
                alt: alt,
                title: title,
              ),
            );
          default:
            inlines.addAll(_parseFb2Inlines(child));
        }
      }
    }
    return inlines;
  }

  List<BookInline> _parseFb2Title(XmlElement titleElement) {
    final paragraphs = titleElement.findElements('p').toList();
    if (paragraphs.isNotEmpty) {
      final inlines = <BookInline>[];
      for (var i = 0; i < paragraphs.length; i++) {
        if (i > 0) inlines.add(const BookLineBreak());
        inlines.addAll(_parseFb2Inlines(paragraphs[i]));
      }
      return inlines;
    }
    return _parseFb2Inlines(
      titleElement,
    ).where((i) => i is! BookText || i.text.trim().isNotEmpty).toList();
  }
}
