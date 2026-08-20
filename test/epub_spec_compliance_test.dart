import 'dart:convert';
import 'dart:typed_data';
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

    test('Font deobfuscation for IDPF and Adobe algorithms', () {
      final dummyFont = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      const uid = 'urn:uuid:12345678-1234-5678-1234-567812345678';

      // Obfuscate with IDPF
      final idpfObfuscated = OcfContainer.deobfuscateFont(
        dummyFont,
        'http://www.idpf.org/2008/embedding',
        uid,
      );
      expect(idpfObfuscated, isNot(equals(dummyFont)));

      // Deobfuscate with IDPF (XOR is symmetric)
      final idpfRestored = OcfContainer.deobfuscateFont(
        idpfObfuscated,
        'http://www.idpf.org/2008/embedding',
        uid,
      );
      expect(idpfRestored, equals(dummyFont));

      // Obfuscate with Adobe
      final adobeObfuscated = OcfContainer.deobfuscateFont(
        dummyFont,
        'http://ns.adobe.com/pdf/enc#RC',
        uid,
      );
      expect(adobeObfuscated, isNot(equals(dummyFont)));

      // Deobfuscate with Adobe (XOR is symmetric)
      final adobeRestored = OcfContainer.deobfuscateFont(
        adobeObfuscated,
        'http://ns.adobe.com/pdf/enc#RC',
        uid,
      );
      expect(adobeRestored, equals(dummyFont));
    });

    test('EPUB 3.3 roundtrip with WebP, audio and video resources', () async {
      final webpBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]);
      final mp3Bytes = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x44, 0x00]);
      final mp4Bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]);

      final book = Book(
        metadata: const BookMetadata(
          id: 'test-epub33-book',
          title: 'EPUB 3.3 Test Book',
          language: 'ru',
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Глава 1')],
              blocks: [
                BookParagraph(inlines: [BookText('Пример текста')]),
                BookImageBlock(ref: BookResourceRef('img-webp'), alt: 'WebP image'),
                BookAudioBlock(ref: BookResourceRef('audio-mp3'), controls: true),
                BookVideoBlock(ref: BookResourceRef('video-mp4'), controls: true),
              ],
            ),
          ],
        ),
        resources: [
          BookResource(id: 'img-webp', mediaType: 'image/webp', bytes: webpBytes),
          BookResource(id: 'audio-mp3', mediaType: 'audio/mpeg', bytes: mp3Bytes),
          BookResource(id: 'video-mp4', mediaType: 'video/mp4', bytes: mp4Bytes),
        ],
      );

      final epubBytes = await EpubConverter.bookToEpub(book);
      expect(epubBytes, isNotEmpty);

      // Verify uncompressed mimetype at offset 30
      expect(String.fromCharCodes(epubBytes.sublist(30, 38)), equals('mimetype'));
      expect(String.fromCharCodes(epubBytes.sublist(38, 58)), equals('application/epub+zip'));

      // Verify OPF contains dcterms:modified and version="3.0"
      final archive = ZipDecoder().decodeBytes(epubBytes);
      final opfFile = archive.findFile('OEBPS/content.opf');
      expect(opfFile, isNotNull);
      final opfContent = utf8.decode(opfFile!.content);
      expect(opfContent, contains('version="3.0"'));
      expect(opfContent, contains('dcterms:modified'));
      expect(opfContent, contains('media-type="image/webp"'));
      expect(opfContent, contains('media-type="audio/mpeg"'));
      expect(opfContent, contains('media-type="video/mp4"'));

      // Decode and verify roundtrip
      final decodedBook = await EpubConverter.epubToBook(epubBytes);
      expect(decodedBook.metadata.title, equals('EPUB 3.3 Test Book'));
      expect(decodedBook.resources.length, equals(3));
      expect(decodedBook.resources.any((r) => r.mediaType == 'image/webp'), isTrue);
      expect(decodedBook.resources.any((r) => r.mediaType == 'audio/mpeg'), isTrue);
      List<BookBlock> allBlocks(List<BookBlock> list) {
        final res = <BookBlock>[];
        for (final b in list) {
          res.add(b);
          if (b is BookSection) res.addAll(allBlocks(b.blocks));
        }
        return res;
      }
      final blocks = allBlocks(decodedBook.content.blocks);
      expect(blocks.any((b) => b is BookAudioBlock), isTrue);
      expect(blocks.any((b) => b is BookVideoBlock), isTrue);
      expect(blocks.any((b) => b is BookImageBlock), isTrue);
    });

    test('EPUB 3.4 roundtrip with AVIF, JPEG XL, and OPUS in MP4 media types', () async {
      final avifBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70, 0x61, 0x76, 0x69, 0x66]);
      final jxlBytes = Uint8List.fromList([0xFF, 0x0A]);
      final opusMp4Bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x6F, 0x70, 0x75, 0x73]);

      final book = Book(
        metadata: const BookMetadata(
          id: 'test-epub34-book',
          title: 'EPUB 3.4 Test Book',
          language: 'ru',
        ),
        content: const BookContent(
          blocks: [
            BookSection(
              title: [BookText('Глава 1: Новые медиатипы EPUB 3.4')],
              blocks: [
                BookParagraph(inlines: [BookText('Тестирование AVIF и JXL')]),
                BookImageBlock(ref: BookResourceRef('img-avif.avif'), alt: 'AVIF image'),
                BookImageBlock(ref: BookResourceRef('img-jxl.jxl'), alt: 'JPEG XL image'),
                BookAudioBlock(ref: BookResourceRef('audio-opus.mp4'), controls: true),
              ],
            ),
          ],
        ),
        resources: [
          BookResource(id: 'img-avif.avif', mediaType: 'image/avif', bytes: avifBytes),
          BookResource(id: 'img-jxl.jxl', mediaType: 'image/jxl', bytes: jxlBytes),
          BookResource(id: 'audio-opus.mp4', mediaType: 'audio/mp4; codecs=opus', bytes: opusMp4Bytes),
        ],
      );

      final epubBytes = await EpubConverter.bookToEpub(book);
      expect(epubBytes, isNotEmpty);

      // Verify OPF contains new 3.4 media types
      final archive = ZipDecoder().decodeBytes(epubBytes);
      final opfFile = archive.findFile('OEBPS/content.opf');
      expect(opfFile, isNotNull);
      final opfContent = utf8.decode(opfFile!.content);
      expect(opfContent, contains('media-type="image/avif"'));
      expect(opfContent, contains('media-type="image/jxl"'));
      expect(opfContent, contains('media-type="audio/mp4; codecs=opus"'));

      // Verify resources extracted correctly
      expect(archive.files.any((f) => f.name.contains('img-avif')), isTrue);
      expect(archive.files.any((f) => f.name.contains('img-jxl')), isTrue);
      expect(archive.files.any((f) => f.name.contains('audio-opus')), isTrue);

      // Decode and verify roundtrip
      final decodedBook = await EpubConverter.epubToBook(epubBytes);
      expect(decodedBook.metadata.title, equals('EPUB 3.4 Test Book'));
      expect(decodedBook.resources.length, equals(3));
      expect(decodedBook.resources.any((r) => r.mediaType == 'image/avif'), isTrue);
      expect(decodedBook.resources.any((r) => r.mediaType == 'image/jxl'), isTrue);
      expect(decodedBook.resources.any((r) => r.mediaType == 'audio/mp4; codecs=opus'), isTrue);
    });

    test('EPUB 2.0.1 complete legacy archive decoding (OPF 2.0, meta cover, NCX TOC, IDPF font)', () async {
      final archive = Archive();

      // 1. mimetype
      final mimetypeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile.noCompress('mimetype', mimetypeBytes.length, mimetypeBytes));

      // 2. container.xml
      const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile('META-INF/container.xml', containerXml.length, utf8.encode(containerXml)));

      // 3. encryption.xml (IDPF obfuscated font)
      const encXml = '''<?xml version="1.0" encoding="UTF-8"?>
<encryption xmlns="http://www.w3.org/2001/04/xmlenc#">
  <EncryptedData>
    <EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <CipherData>
      <CipherReference URI="fonts/font.otf"/>
    </CipherData>
  </EncryptedData>
</encryption>''';
      archive.addFile(ArchiveFile('META-INF/encryption.xml', encXml.length, utf8.encode(encXml)));

      // 4. content.opf (EPUB 2.0 package)
      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>EPUB 2 Legacy Book</dc:title>
    <dc:language>ru</dc:language>
    <dc:identifier id="BookId">urn:uuid:legacy-epub2-book-id-999</dc:identifier>
    <dc:creator opf:role="aut">Иван Тургенев</dc:creator>
    <meta name="cover" content="cover-image-id"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-image-id" href="images/cover.jpg" media-type="image/jpeg"/>
    <item id="chapter1" href="text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="font1" href="fonts/font.otf" media-type="font/opentype"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>''';
      archive.addFile(ArchiveFile('content.opf', opfXml.length, utf8.encode(opfXml)));

      // 5. toc.ncx
      const ncxXml = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:legacy-epub2-book-id-999"/>
  </head>
  <docTitle><text>EPUB 2 Legacy Book</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>Отцы и дети: Глава 1</text></navLabel>
      <content src="text/chapter1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''';
      archive.addFile(ArchiveFile('toc.ncx', ncxXml.length, utf8.encode(ncxXml)));

      // 6. text/chapter1.xhtml
      const chapXhtml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Глава 1</title></head>
  <body>
    <h1>Отцы и дети</h1>
    <p>Что, Петр, не видать еще?</p>
  </body>
</html>''';
      archive.addFile(ArchiveFile('text/chapter1.xhtml', chapXhtml.length, utf8.encode(chapXhtml)));

      // 7. images/cover.jpg
      final coverBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      archive.addFile(ArchiveFile('images/cover.jpg', coverBytes.length, coverBytes));

      // 8. fonts/font.otf (Obfuscated using IDPF)
      final rawFontBytes = Uint8List.fromList(List.generate(1200, (i) => (i * 7) % 256));
      final obfuscatedFontBytes = OcfContainer.deobfuscateFont(
        rawFontBytes,
        'http://www.idpf.org/2008/embedding',
        'urn:uuid:legacy-epub2-book-id-999',
      );
      archive.addFile(ArchiveFile('fonts/font.otf', obfuscatedFontBytes.length, obfuscatedFontBytes));

      // Encode archive to bytes
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      // Decode with EpubDecoder
      final book = await EpubConverter.epubToBook(zipBytes);

      // Verify metadata
      expect(book.metadata.title, equals('EPUB 2 Legacy Book'));
      expect(book.metadata.language, equals('ru'));
      expect(book.metadata.id, equals('urn:uuid:legacy-epub2-book-id-999'));
      expect(book.metadata.contributors.first.name.display, equals('Иван Тургенев'));

      // Verify EPUB 2 cover extraction via <meta name="cover">
      expect(book.metadata.cover, isNotNull);
      expect(book.metadata.cover!.ref.id, equals('epub-res-cover-image-id'));

      // Verify resources
      expect(book.resources.length, equals(2));
      final coverRes = book.resources.firstWhere((r) => r.id == 'epub-res-cover-image-id');
      expect(coverRes.bytes, equals(coverBytes));
      expect(coverRes.mediaType, equals('image/jpeg'));

      // Verify font deobfuscation
      final fontRes = book.resources.firstWhere((r) => r.id == 'epub-res-font1');
      expect(fontRes.bytes, equals(rawFontBytes));

      // Verify TOC parsed from toc.ncx
      expect(book.content.blocks.length, equals(1));
      final section = book.content.blocks.first as BookSection;
      expect((section.title.first as BookText).text, equals('Отцы и дети: Глава 1'));
    });
  });
}


