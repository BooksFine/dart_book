import 'package:xml/xml.dart';
import 'epub_nav_parser.dart';

class EpubNcxDocument {
  final List<EpubNavEntry> navMap;

  const EpubNcxDocument({this.navMap = const []});

  static EpubNcxDocument parseFromString(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final navMapElement = document.findAllElements('navMap').firstOrNull;
    if (navMapElement == null) return const EpubNcxDocument();

    final entries = <EpubNavEntry>[];
    for (final child in navMapElement.children.whereType<XmlElement>()) {
      if (child.localName == 'navPoint') {
        entries.add(_parseNavPoint(child));
      }
    }

    return EpubNcxDocument(navMap: entries);
  }

  static EpubNavEntry _parseNavPoint(XmlElement navPoint) {
    final label = navPoint.findElements('navLabel').firstOrNull?.innerText.trim() ?? '';
    final src = navPoint.findElements('content').firstOrNull?.getAttribute('src') ?? '';

    final children = <EpubNavEntry>[];
    for (final child in navPoint.children.whereType<XmlElement>()) {
      if (child.localName == 'navPoint') {
        children.add(_parseNavPoint(child));
      }
    }

    return EpubNavEntry(title: label, href: src, children: children);
  }
}
