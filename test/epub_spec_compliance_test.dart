import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('EPUB 3.3 / 3.4 Spec Compliance Tests', () {
    test('OCF Container parses container.xml correctly', () {
      final archive = Archive();
      const containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';
      archive.addFile(
        ArchiveFile('META-INF/container.xml', containerXml.length, utf8.encode(containerXml)),
      );

      final ocf = OcfContainer.fromArchive(archive);
      expect(ocf.primaryOpfPath, equals('OEBPS/content.opf'));
    });

    test('Detects encrypted DRM resources in encryption.xml', () {
      final archive = Archive();
      const encXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<encryption xmlns="http://www.w3.org/2001/04/xmlenc#">
  <EncryptedData>
    <EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>
    <CipherData>
      <CipherReference URI="OEBPS/fonts/font.otf"/>
    </CipherData>
  </EncryptedData>
</encryption>
''';
      archive.addFile(
        ArchiveFile('META-INF/encryption.xml', encXml.length, utf8.encode(encXml)),
      );

      final paths = OcfContainer.parseEncryptionPaths(archive);
      expect(paths, contains('OEBPS/fonts/font.otf'));
    });

    test('Parses nav.xhtml TOC structure', () {
      const navXhtml = '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <h1>Table of Contents</h1>
      <ol>
        <li><a href="chap1.xhtml">Chapter 1</a></li>
        <li><a href="chap2.xhtml">Chapter 2</a></li>
      </ol>
    </nav>
  </body>
</html>
''';
      final navDoc = EpubNavDocument.parseFromString(navXhtml);
      expect(navDoc.toc.length, equals(2));
      expect(navDoc.toc[0].title, equals('Chapter 1'));
      expect(navDoc.toc[0].href, equals('chap1.xhtml'));
    });

    test('Parses legacy EPUB 2 NCX navMap structure', () {
      const ncxXml = '''
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np-1" playOrder="1">
      <navLabel><text>Prologue</text></navLabel>
      <content src="prologue.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''';
      final ncxDoc = EpubNcxDocument.parseFromString(ncxXml);
      expect(ncxDoc.navMap.length, equals(1));
      expect(ncxDoc.navMap[0].title, equals('Prologue'));
      expect(ncxDoc.navMap[0].href, equals('prologue.xhtml'));
    });

    test('Parses SMIL 3.0 Media Overlays audio sync clips', () {
      const smilXml = '''
<smil xmlns="http://www.w3.org/ns/SMIL" version="3.0">
  <body>
    <par id="par1">
      <text src="chap1.xhtml#p1"/>
      <audio src="audio/chap1.mp3" clipBegin="0s" clipEnd="12.5s"/>
    </par>
  </body>
</smil>
''';
      final smilDoc = EpubSmilDocument.parseFromString(smilXml);
      expect(smilDoc.clips.length, equals(1));
      expect(smilDoc.clips[0].textRef, equals('chap1.xhtml#p1'));
      expect(smilDoc.clips[0].audioSrc, equals('audio/chap1.mp3'));
      expect(smilDoc.clips[0].clipBegin, equals(0.0));
      expect(smilDoc.clips[0].clipEnd, equals(12.5));
    });

    test('HtmlParser parses audio, video, MathML, and SVG', () {
      const html = '''
        <audio src="sound.mp3" controls="controls"></audio>
        <video src="movie.mp4" poster="cover.jpg" controls="controls"></video>
        <math><mrow><mi>a</mi></mrow></math>
        <svg><circle cx="50" cy="50" r="40"/></svg>
      ''';
      final parser = HtmlParser();
      final blocks = parser.parseFromString(html);

      expect(blocks.length, equals(4));
      expect(blocks[0], isA<BookAudioBlock>());
      expect(blocks[1], isA<BookVideoBlock>());
      expect(blocks[2], isA<BookMathBlock>());
      expect(blocks[3], isA<BookSvgBlock>());
    });
  });
}
