import 'package:xml/xml.dart';
import '../models/book.dart';
import '../models/parser.dart';

/// Парсер контента для формата FictionBook 2 (FB2).
/// Реализует интерфейс [Parser] для преобразования XML-фрагментов в блоки книги.
class Fb2Parser implements Parser<Iterable<XmlNode>> {
  @override
  final BookResourceRegistrar? registrar;

  Fb2Parser({this.registrar});

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
            ? _parseFb2Inlines(titleElement)
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
      case 'subtitle':
        return [BookHeading(level: 2, text: _parseFb2Inlines(element))];
      case 'empty-line':
        return [const BookEmptyLine()];
      case 'image':
        final href =
            element.getAttribute('l:href') ??
            element.getAttribute('href') ??
            '';
        final id =
            registrar?.call(href, isInline: false) ??
            (href.startsWith('#') ? href.substring(1) : href);
        return [BookImageBlock(ref: BookResourceRef(id))];
      case 'body':
        return parse(element.children);
      default:
        return [];
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
            inlines.add(BookEmphasis(children: _parseInlines(child)));
          case 'a':
            final href =
                child.getAttribute('l:href') ??
                child.getAttribute('href') ??
                '';
            inlines.add(
              BookLink(
                href: Uri.parse(href),
                children: _parseFb2Inlines(child),
              ),
            );
          case 'image':
            final href =
                child.getAttribute('l:href') ??
                child.getAttribute('href') ??
                '';
            final id =
                registrar?.call(href, isInline: true) ??
                (href.startsWith('#') ? href.substring(1) : href);
            inlines.add(BookImageInline(ref: BookResourceRef(id)));
          default:
            inlines.addAll(_parseFb2Inlines(child));
        }
      }
    }
    return inlines;
  }

  // Для совместимости с внутренним вызовом
  List<BookInline> _parseInlines(XmlElement element) =>
      _parseFb2Inlines(element);
}
