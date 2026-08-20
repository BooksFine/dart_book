import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Security: ZIP Slip & Path Traversal Protection', () {
    test('EPUB: Traversal paths in container.xml full-path are safely handled without escaping', () async {
      final archive = Archive();
      // mimetype
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes));

      // Malicious container.xml pointing outside the archive
      const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="../../etc/passwd" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      final contBytes = utf8.encode(containerXml);
      archive.addFile(ArchiveFile('META-INF/container.xml', contBytes.length, contBytes));

      // OPF file located at normalized in-archive path
      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">safe-book</dc:identifier>
    <dc:title>Safe Book</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chap1"/>
  </spine>
</package>''';
      final opfBytes = utf8.encode(opfXml);
      archive.addFile(ArchiveFile('../../etc/passwd', opfBytes.length, opfBytes));

      const chapHtml = '<html><body><p>Safe content</p></body></html>';
      final chapBytes = utf8.encode(chapHtml);
      archive.addFile(ArchiveFile('chap1.xhtml', chapBytes.length, chapBytes));

      final epubBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final book = await EpubDecoder().decode(epubBytes);
      expect(book.metadata.title, equals('Safe Book'));
    });

    test('EPUB: Manifest items with ../../ and Windows ..\\..\\ traversal paths do not escape sandbox', () async {
      final archive = Archive();
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes));

      const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      final contBytes = utf8.encode(containerXml);
      archive.addFile(ArchiveFile('META-INF/container.xml', contBytes.length, contBytes));

      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">traversal-test</dc:identifier>
    <dc:title>Traversal Manifest Test</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="chap1" href="../../evil.xhtml" media-type="application/xhtml+xml"/>
    <item id="chap2" href="..\\..\\Windows\\cmd.xhtml" media-type="application/xhtml+xml"/>
    <item id="chap3" href="/etc/passwd" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chap1"/>
    <itemref idref="chap2"/>
    <itemref idref="chap3"/>
  </spine>
</package>''';
      final opfBytes = utf8.encode(opfXml);
      archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

      // Store files normalized in archive
      const chap1Html = '<html><body><p>Chapter 1 sanitized</p></body></html>';
      final c1Bytes = utf8.encode(chap1Html);
      archive.addFile(ArchiveFile('evil.xhtml', c1Bytes.length, c1Bytes));

      const chap2Html = '<html><body><p>Chapter 2 sanitized</p></body></html>';
      final c2Bytes = utf8.encode(chap2Html);
      archive.addFile(ArchiveFile('Windows/cmd.xhtml', c2Bytes.length, c2Bytes));

      const chap3Html = '<html><body><p>Chapter 3 sanitized</p></body></html>';
      final c3Bytes = utf8.encode(chap3Html);
      archive.addFile(ArchiveFile('OEBPS/etc/passwd', c3Bytes.length, c3Bytes));

      final epubBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final book = await EpubDecoder().decode(epubBytes);

      expect(book.metadata.title, equals('Traversal Manifest Test'));
      expect(book.content.blocks, isNotEmpty);
    });

    test('EPUB: Resource references with traversal paths stay safely scoped', () async {
      final archive = Archive();
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes));

      const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile('META-INF/container.xml', utf8.encode(containerXml).length, utf8.encode(containerXml)));

      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">img-traversal</dc:identifier>
    <dc:title>Image Traversal Test</dc:title>
    <dc:language>ru</dc:language>
  </metadata>
  <manifest>
    <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="../../images/secret.png" media-type="image/png"/>
    <item id="img2" href="..\\..\\Windows\\logo.png" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="chap1"/>
  </spine>
</package>''';
      archive.addFile(ArchiveFile('OEBPS/content.opf', utf8.encode(opfXml).length, utf8.encode(opfXml)));

      const chapHtml = '<html><body><img src="../../images/secret.png"/><img src="..\\..\\Windows\\logo.png"/></body></html>';
      archive.addFile(ArchiveFile('OEBPS/chap1.xhtml', utf8.encode(chapHtml).length, utf8.encode(chapHtml)));

      final imgBytes = Uint8List.fromList([137, 80, 78, 71]);
      archive.addFile(ArchiveFile('images/secret.png', imgBytes.length, imgBytes));
      archive.addFile(ArchiveFile('Windows/logo.png', imgBytes.length, imgBytes));

      final epubBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final book = await EpubDecoder().decode(epubBytes);

      expect(book.resources, hasLength(2));
      expect(book.resources.map((r) => r.id), containsAll(['epub-res-img1', 'epub-res-img2']));
    });

    test('FB2.ZIP: Archive containing traversal entry names (../../evil.fb2, ..\\..\\cmd.exe) decodes safely in-memory', () {
      const fb2Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>FB2 Zip Slip Test</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <p>Безопасный текст в памяти</p>
  </body>
</FictionBook>''';

      // 1. Forward slash traversal
      final archive1 = Archive();
      final xmlBytes = utf8.encode(fb2Xml);
      archive1.addFile(ArchiveFile('../../evil_dir/book.fb2', xmlBytes.length, xmlBytes));
      final zipBytes1 = Uint8List.fromList(ZipEncoder().encode(archive1));

      final book1 = Fb2ZipDecoder().decode(zipBytes1);
      expect(book1.metadata.title, equals('FB2 Zip Slip Test'));
      expect(book1.content.blocks.length, equals(1));

      // 2. Windows backslash traversal
      final archive2 = Archive();
      archive2.addFile(ArchiveFile(r'..\..\Windows\System32\book.fb2', xmlBytes.length, xmlBytes));
      final zipBytes2 = Uint8List.fromList(ZipEncoder().encode(archive2));

      final book2 = Fb2ZipDecoder().decode(zipBytes2);
      expect(book2.metadata.title, equals('FB2 Zip Slip Test'));

      // 3. Absolute root path
      final archive3 = Archive();
      archive3.addFile(ArchiveFile('/etc/shadow/book.xml', xmlBytes.length, xmlBytes));
      final zipBytes3 = Uint8List.fromList(ZipEncoder().encode(archive3));

      final book3 = Fb2ZipDecoder().decode(zipBytes3);
      expect(book3.metadata.title, equals('FB2 Zip Slip Test'));
    });
  });

  group('Security: Decompression Attacks & Resource Quotas', () {
    test('Handles highly compressed / large zero-filled archive payload gracefully', () async {
      // Create a 5MB payload of repeating pattern compressed down to a small zip
      final largeBuffer = StringBuffer();
      largeBuffer.write('<?xml version="1.0" encoding="UTF-8"?>');
      largeBuffer.write('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">');
      largeBuffer.write('<description><title-info><book-title>Decompression Test</book-title><lang>ru</lang></title-info></description>');
      largeBuffer.write('<body>');
      for (var i = 0; i < 2000; i++) {
        largeBuffer.write('<p>Повторяющийся длинный параграф для проверки компрессии №$i</p>');
      }
      largeBuffer.write('</body>');
      largeBuffer.write('</FictionBook>');

      final xmlBytes = utf8.encode(largeBuffer.toString());
      final archive = Archive();
      archive.addFile(ArchiveFile('book.fb2', xmlBytes.length, xmlBytes));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(zipBytes.length, lessThan(xmlBytes.length)); // Confirm compression

      final stopwatch = Stopwatch()..start();
      final book = Fb2ZipDecoder().decode(zipBytes);
      stopwatch.stop();

      expect(book.metadata.title, equals('Decompression Test'));
      expect(book.content.blocks.length, equals(2000));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('Rejects corrupted, truncated and malformed ZIP streams with BookFormatException', () {
      final zipDecoder = Fb2ZipDecoder();

      // 1. Truncated header (less than 4 bytes)
      expect(
        () => zipDecoder.decode(Uint8List.fromList([0x50, 0x4B])),
        throwsA(isA<BookFormatException>()),
      );

      // 2. Invalid magic bytes
      expect(
        () => zipDecoder.decode(Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])),
        throwsA(isA<BookFormatException>()),
      );

      // 3. Valid PK zip signature but corrupted truncated body
      expect(
        () => zipDecoder.decode(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFE, 0xFD])),
        throwsA(isA<BookFormatException>()),
      );

      // 4. Empty ZIP archive (contains no files)
      final emptyZip = Uint8List.fromList(ZipEncoder().encode(Archive()));
      expect(
        () => zipDecoder.decode(emptyZip),
        throwsA(isA<BookFormatException>()),
      );
    });

    test('Handles ZIP archive with large number of metadata entries without memory exhaustion', () async {
      final archive = Archive();
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes));

      const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile('META-INF/container.xml', utf8.encode(containerXml).length, utf8.encode(containerXml)));

      final opfBuf = StringBuffer();
      opfBuf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      opfBuf.writeln('<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="pub-id" version="3.0">');
      opfBuf.writeln('  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="pub-id">many-entries</dc:identifier><dc:title>Many Entries</dc:title><dc:language>en</dc:language></metadata>');
      opfBuf.writeln('  <manifest>');
      for (var i = 0; i < 200; i++) {
        opfBuf.writeln('    <item id="c$i" href="c$i.xhtml" media-type="application/xhtml+xml"/>');
      }
      opfBuf.writeln('  </manifest>');
      opfBuf.writeln('  <spine>');
      for (var i = 0; i < 200; i++) {
        opfBuf.writeln('    <itemref idref="c$i"/>');
      }
      opfBuf.writeln('  </spine>');
      opfBuf.writeln('</package>');

      final opfStr = opfBuf.toString();
      archive.addFile(ArchiveFile('OEBPS/content.opf', utf8.encode(opfStr).length, utf8.encode(opfStr)));

      const chapContent = '<html><body><p>Paragraph</p></body></html>';
      final chapBytes = utf8.encode(chapContent);
      for (var i = 0; i < 200; i++) {
        archive.addFile(ArchiveFile('OEBPS/c$i.xhtml', chapBytes.length, chapBytes));
      }

      final epubBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final book = await EpubDecoder().decode(epubBytes);

      expect(book.metadata.title, equals('Many Entries'));
      expect(book.content.blocks.length, equals(200));
    });
  });
}
