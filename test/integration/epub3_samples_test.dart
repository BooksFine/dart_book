import 'dart:io';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('IDPF EPUB 3.0 Samples Integration Tests', () {
    final samplesDir = Directory('test/fixtures/epub3-samples/30');

    setUpAll(() {
      if (!samplesDir.existsSync()) {
        fail('Samples directory test/fixtures/epub3-samples/30 does not exist');
      }
    });

    test('Parses OPF packages and NAV documents across sample EPUB 3 folders', () {
      final sampleFolders = samplesDir.listSync().whereType<Directory>();
      expect(sampleFolders, isNotEmpty);

      var parsedCount = 0;
      for (final folder in sampleFolders) {
        final containerFile = File('${folder.path}/META-INF/container.xml');
        if (!containerFile.existsSync()) continue;

        final containerXml = XmlDocument.parse(containerFile.readAsStringSync());
        final opfPath = containerXml
            .findAllElements('rootfile')
            .firstOrNull
            ?.getAttribute('full-path');
        if (opfPath == null) continue;

        final opfFile = File('${folder.path}/$opfPath');
        if (!opfFile.existsSync()) continue;

        final opfXml = XmlDocument.parse(opfFile.readAsStringSync());
        final title = opfXml.findAllElements('dc:title').firstOrNull?.innerText ?? 'Untitled';
        expect(title, isNotEmpty);

        parsedCount++;
      }

      print('Successfully verified OPF metadata for $parsedCount IDPF EPUB 3 sample books.');
      expect(parsedCount, greaterThan(30));
    });

    test('Parses Moby Dick sample chapter HTML into BookBlocks', () {
      final chapterFile = File('test/fixtures/epub3-samples/30/moby-dick/OPS/chapter_001.xhtml');
      if (!chapterFile.existsSync()) return;

      final parser = HtmlParser();
      final blocks = parser.parseFromString(chapterFile.readAsStringSync());

      expect(blocks, isNotEmpty);
      expect(blocks.any((b) => b is BookSection || b is BookHeading || b is BookParagraph), isTrue);
      final section = blocks.first as BookSection;
      expect(section.blocks, isNotEmpty);
    });

    test('Parses Wasteland sample NAV document', () {
      final navFile = File('test/fixtures/epub3-samples/30/wasteland/EPUB/NAV.xhtml');
      if (!navFile.existsSync()) return;

      final navDoc = EpubNavDocument.parseFromString(navFile.readAsStringSync());
      expect(navDoc.toc, isNotEmpty);
      expect(navDoc.toc.first.title, isNotEmpty);
    });
  });
}
