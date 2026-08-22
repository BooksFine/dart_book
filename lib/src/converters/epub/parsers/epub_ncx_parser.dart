import 'package:xml/xml.dart';
import 'epub_nav_parser.dart';

class EpubNcxDocument {
  final List<EpubNavEntry> navMap;

  const EpubNcxDocument({this.navMap = const []});

  static EpubNcxDocument parseFromString(
    String xmlContent, {
    int maxDepth = 32,
  }) {
    final document = XmlDocument.parse(xmlContent);
    final navMapElement = document.findAllElements('navMap').firstOrNull;
    if (navMapElement == null) return const EpubNcxDocument();

    final entries = <EpubNavEntry>[];
    final visited = <XmlElement>{};
    for (final child in navMapElement.children.whereType<XmlElement>()) {
      if (child.localName == 'navPoint') {
        entries.add(_parseNavPoint(child, visited, 0, maxDepth));
      }
    }

    return EpubNcxDocument(navMap: entries);
  }

  static EpubNavEntry _parseNavPoint(
    XmlElement navPoint,
    Set<XmlElement> visited,
    int depth,
    int maxDepth,
  ) {
    final label =
        navPoint.findElements('navLabel').firstOrNull?.innerText.trim() ?? '';
    final src =
        navPoint.findElements('content').firstOrNull?.getAttribute('src') ?? '';

    if (depth >= maxDepth || visited.contains(navPoint)) {
      return EpubNavEntry(title: label, href: src, children: const []);
    }
    visited.add(navPoint);

    final children = <EpubNavEntry>[];
    for (final child in navPoint.children.whereType<XmlElement>()) {
      if (child.localName == 'navPoint') {
        children.add(_parseNavPoint(child, visited, depth + 1, maxDepth));
      }
    }

    return EpubNavEntry(title: label, href: src, children: children);
  }
}
