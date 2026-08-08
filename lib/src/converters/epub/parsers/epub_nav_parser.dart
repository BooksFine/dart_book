import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

class EpubNavEntry {
  final String title;
  final String href;
  final List<EpubNavEntry> children;

  const EpubNavEntry({
    required this.title,
    required this.href,
    this.children = const [],
  });
}

class EpubNavLandmark {
  final String type;
  final String title;
  final String href;

  const EpubNavLandmark({
    required this.type,
    required this.title,
    required this.href,
  });
}

class EpubNavDocument {
  final List<EpubNavEntry> toc;
  final List<EpubNavLandmark> landmarks;

  const EpubNavDocument({
    this.toc = const [],
    this.landmarks = const [],
  });

  static EpubNavDocument parseFromString(String xhtmlContent) {
    final document = html.parse(xhtmlContent);
    
    final tocEntries = <EpubNavEntry>[];
    final landmarkEntries = <EpubNavLandmark>[];

    for (final nav in document.querySelectorAll('nav')) {
      final epubType = nav.attributes['epub:type'] ?? nav.attributes['type'] ?? '';
      if (epubType.contains('toc')) {
        final ol = nav.querySelector('ol');
        if (ol != null) {
          tocEntries.addAll(_parseOl(ol));
        }
      } else if (epubType.contains('landmarks')) {
        final ol = nav.querySelector('ol');
        if (ol != null) {
          for (final a in ol.querySelectorAll('a')) {
            final href = a.attributes['href'];
            final type = a.attributes['epub:type'] ?? a.attributes['type'] ?? '';
            final title = a.text.trim();
            if (href != null && href.isNotEmpty) {
              landmarkEntries.add(EpubNavLandmark(type: type, title: title, href: href));
            }
          }
        }
      }
    }

    return EpubNavDocument(toc: tocEntries, landmarks: landmarkEntries);
  }

  static List<EpubNavEntry> _parseOl(dom.Element ol) {
    final entries = <EpubNavEntry>[];
    for (final li in ol.children.where((c) => c.localName == 'li')) {
      final a = li.children.firstWhere(
        (c) => c.localName == 'a',
        orElse: () => dom.Element.tag('a'),
      );
      final href = a.attributes['href'] ?? '';
      final title = a.text.trim();

      final nestedOl = li.children.firstWhere(
        (c) => c.localName == 'ol',
        orElse: () => dom.Element.tag('ol'),
      );
      final children = nestedOl.localName == 'ol' ? _parseOl(nestedOl) : const <EpubNavEntry>[];

      if (title.isNotEmpty || href.isNotEmpty) {
        entries.add(EpubNavEntry(title: title, href: href, children: children));
      }
    }
    return entries;
  }
}
