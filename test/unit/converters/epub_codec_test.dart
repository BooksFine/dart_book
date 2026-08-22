import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

import '../../utils/ast_normalizer.dart';
import '../../utils/golden_comparator.dart';

void main() {
  group('EPUB Codec Unit Tests (EpubDecoder, EpubEncoder, OcfContainer, Nav/Ncx)', () {
    // -------------------------------------------------------------------------
    // 1. OCF Container & Uncompressed Mimetype Layout
    // -------------------------------------------------------------------------
    group('OCF Container: uncompressed mimetype and META-INF/container.xml', () {
      test('EpubEncoder writes uncompressed mimetype at offset 0 (0..58 bytes)', () {
        final book = Book(
          metadata: const BookMetadata(
            id: 'mimetype-test',
            title: 'Mimetype Test',
            language: 'en',
          ),
          content: const BookContent(
            blocks: [
              BookParagraph(inlines: [BookText('Hello EPUB')]),
            ],
          ),
          resources: const [],
        );

        final encoder = EpubEncoder();
        final bytes = encoder.encode(book);

        // 1. Check ZIP Local File Header magic bytes at offset 0..3: PK\x03\x04
        expect(bytes[0], equals(0x50));
        expect(bytes[1], equals(0x4B));
        expect(bytes[2], equals(0x03));
        expect(bytes[3], equals(0x04));

        // 2. Check compression method at offset 8..9: 0 (STORED / uncompressed)
        expect(bytes[8], equals(0x00));
        expect(bytes[9], equals(0x00));

        // 3. Check filename length at offset 26..27: 8 ('mimetype')
        expect(bytes[26], equals(8));
        expect(bytes[27], equals(0));

        // 4. Check extra field length at offset 28..29: 0
        expect(bytes[28], equals(0));
        expect(bytes[29], equals(0));

        // 5. Check filename at offset 30..37: 'mimetype'
        final filename = String.fromCharCodes(bytes.sublist(30, 38));
        expect(filename, equals('mimetype'));

        // 6. Check uncompressed payload at offset 38..57: 'application/epub+zip'
        final payload = String.fromCharCodes(bytes.sublist(38, 58));
        expect(payload, equals('application/epub+zip'));

        // 7. Test canDecode with these valid bytes
        final decoder = EpubDecoder();
        expect(decoder.canDecode(bytes, extension: 'epub'), isTrue);
      });

      test(
        'OcfContainer parses single and multiple rootfiles from container.xml',
        () {
          final archive = Archive();
          const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/>
    <rootfile full-path="EPUB/alt-package.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
          archive.addFile(
            ArchiveFile(
              'META-INF/container.xml',
              containerXml.length,
              utf8.encode(containerXml),
            ),
          );

          final ocf = OcfContainer.fromArchive(archive);
          expect(ocf.rootfiles.length, equals(2));
          expect(ocf.rootfiles[0].fullPath, equals('EPUB/package.opf'));
          expect(ocf.rootfiles[1].fullPath, equals('EPUB/alt-package.opf'));
          expect(ocf.primaryOpfPath, equals('EPUB/package.opf'));
        },
      );
    });

    // -------------------------------------------------------------------------
    // 2. Font Deobfuscation (IDPF & Adobe algorithms with OTTO/TTF validation)
    // -------------------------------------------------------------------------
    group('Font Deobfuscation: IDPF (SHA-1) and Adobe (UUID XOR) algorithms', () {
      test(
        'IDPF Font Deobfuscation: verifies OpenType (OTTO) font header reconstruction',
        () {
          const publicationUid = 'urn:uuid:978-0-123456-47-2';
          final cleanUid = publicationUid.replaceAll(RegExp(r'[\s\t\r\n]'), '');

          // 1. Create valid OpenType (CFF) font bytes starting with 'OTTO' (0x4F, 0x54, 0x54, 0x4F)
          final rawFontBytes = Uint8List(1500);
          rawFontBytes[0] = 0x4F; // 'O'
          rawFontBytes[1] = 0x54; // 'T'
          rawFontBytes[2] = 0x54; // 'T'
          rawFontBytes[3] = 0x4F; // 'O'
          for (var i = 4; i < rawFontBytes.length; i++) {
            rawFontBytes[i] = (i * 37) % 256;
          }

          // Verify initial magic header
          expect(
            String.fromCharCodes(rawFontBytes.sublist(0, 4)),
            equals('OTTO'),
          );

          // 2. Obfuscate using IDPF algorithm (XOR first 1040 bytes with SHA-1 key)
          final key = sha1.convert(utf8.encode(cleanUid)).bytes;
          final obfuscatedBytes = Uint8List.fromList(rawFontBytes);
          for (var i = 0; i < 1040; i++) {
            obfuscatedBytes[i] ^= key[i % key.length];
          }

          // Verify that obfuscated header is scrambled and NO LONGER matches 'OTTO'
          expect(
            String.fromCharCodes(obfuscatedBytes.sublist(0, 4)),
            isNot(equals('OTTO')),
          );

          // 3. Deobfuscate via OcfContainer
          final restoredBytes = OcfContainer.deobfuscateFont(
            obfuscatedBytes,
            'http://www.idpf.org/2008/embedding',
            publicationUid,
          );

          // 4. Verify that magic header 'OTTO' is restored and all bytes match original exactly
          expect(
            String.fromCharCodes(restoredBytes.sublist(0, 4)),
            equals('OTTO'),
          );
          expect(restoredBytes, equals(rawFontBytes));
        },
      );

      test(
        'Adobe Font Deobfuscation: verifies TrueType (\\x00\\x01\\x00\\x00) font header reconstruction',
        () {
          const publicationUid =
              'urn:uuid:48e24440-2b47-49f3-8b77-84883448f7a6';

          // 1. Create valid TrueType font bytes starting with 0x00, 0x01, 0x00, 0x00
          final rawFontBytes = Uint8List(1200);
          rawFontBytes[0] = 0x00;
          rawFontBytes[1] = 0x01;
          rawFontBytes[2] = 0x00;
          rawFontBytes[3] = 0x00;
          for (var i = 4; i < rawFontBytes.length; i++) {
            rawFontBytes[i] = (i * 19) % 256;
          }

          // 2. Obfuscate using Adobe algorithm (XOR first 1024 bytes with 16-byte UUID key)
          final hex = publicationUid
              .replaceAll('urn:uuid:', '')
              .replaceAll('-', '')
              .replaceAll(':', '');
          final key = <int>[];
          for (var i = 0; i < hex.length - 1 && key.length < 16; i += 2) {
            key.add(int.parse(hex.substring(i, i + 2), radix: 16));
          }

          final obfuscatedBytes = Uint8List.fromList(rawFontBytes);
          for (var i = 0; i < 1024; i++) {
            obfuscatedBytes[i] ^= key[i % key.length];
          }

          // Verify that obfuscated header does not match TTF magic
          expect(
            obfuscatedBytes.sublist(0, 4),
            isNot(equals([0x00, 0x01, 0x00, 0x00])),
          );

          // 3. Deobfuscate via OcfContainer
          final restoredBytes = OcfContainer.deobfuscateFont(
            obfuscatedBytes,
            'http://ns.adobe.com/pdf/enc#RC',
            publicationUid,
          );

          // 4. Verify TrueType header restoration
          expect(restoredBytes.sublist(0, 4), equals([0x00, 0x01, 0x00, 0x00]));
          expect(restoredBytes, equals(rawFontBytes));
        },
      );

      test(
        'Handles small font files (< 1024 / 1040 bytes) and empty bytes safely',
        () {
          const uid = 'urn:uuid:abcdef01-2345-6789-abcd-ef0123456789';

          // 1. Small 300-byte font
          final smallFont = Uint8List.fromList(
            List.generate(300, (i) => (i * 7) % 256),
          );
          final obfIdpf = OcfContainer.deobfuscateFont(
            smallFont,
            'http://www.idpf.org/2008/embedding',
            uid,
          );
          final restIdpf = OcfContainer.deobfuscateFont(
            obfIdpf,
            'http://www.idpf.org/2008/embedding',
            uid,
          );
          expect(restIdpf, equals(smallFont));

          final obfAdobe = OcfContainer.deobfuscateFont(
            smallFont,
            'http://ns.adobe.com/pdf/enc#RC',
            uid,
          );
          final restAdobe = OcfContainer.deobfuscateFont(
            obfAdobe,
            'http://ns.adobe.com/pdf/enc#RC',
            uid,
          );
          expect(restAdobe, equals(smallFont));

          // 2. Empty byte array
          final emptyBytes = Uint8List(0);
          expect(
            OcfContainer.deobfuscateFont(
              emptyBytes,
              'http://www.idpf.org/2008/embedding',
              uid,
            ),
            isEmpty,
          );
        },
      );

      test(
        'End-to-end EpubDecoder font deobfuscation from archive with META-INF/encryption.xml',
        () async {
          const pubUid = 'book-uid-456';
          final rawFont = Uint8List(1200);
          rawFont[0] = 0x4F; // 'O'
          rawFont[1] = 0x54; // 'T'
          rawFont[2] = 0x54; // 'T'
          rawFont[3] = 0x4F; // 'O'
          for (var i = 4; i < rawFont.length; i++) {
            rawFont[i] = (i * 23) % 256;
          }

          final obfFont = OcfContainer.deobfuscateFont(
            rawFont,
            'http://www.idpf.org/2008/embedding',
            pubUid,
          );

          final archive = Archive();
          archive.addFile(
            ArchiveFile.noCompress(
              'mimetype',
              20,
              utf8.encode('application/epub+zip'),
            ),
          );
          archive.addFile(
            ArchiveFile(
              'META-INF/container.xml',
              180,
              utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
            ),
          );
          archive.addFile(
            ArchiveFile(
              'META-INF/encryption.xml',
              250,
              utf8.encode('''<?xml version="1.0"?>
<encryption xmlns="http://www.w3.org/2001/04/xmlenc#">
  <EncryptedData>
    <EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <CipherData><CipherReference URI="fonts/font.otf"/></CipherData>
  </EncryptedData>
</encryption>'''),
            ),
          );
          archive.addFile(
            ArchiveFile(
              'OEBPS/content.opf',
              350,
              utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">$pubUid</dc:identifier>
    <dc:title>Font Deobfuscation Test</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ch1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="font1" href="fonts/font.otf" media-type="font/otf"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
            ),
          );
          archive.addFile(
            ArchiveFile(
              'OEBPS/chap1.xhtml',
              100,
              utf8.encode('<html><body><p>Text</p></body></html>'),
            ),
          );
          archive.addFile(
            ArchiveFile('OEBPS/fonts/font.otf', obfFont.length, obfFont),
          );

          final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
          final book = await EpubDecoder().decode(zipBytes);

          expect(book.resources.length, equals(1));
          final fontRes = book.resources.first;
          expect(
            fontRes.bytes.sublist(0, 4),
            equals([0x4F, 0x54, 0x54, 0x4F]),
          ); // 'OTTO'
          expect(fontRes.bytes, equals(rawFont));
        },
      );
    });

    // -------------------------------------------------------------------------
    // 3. Dual Navigation: EPUB 3 nav.xhtml and EPUB 2 toc.ncx
    // -------------------------------------------------------------------------
    group('Dual Navigation (EPUB 3 nav.xhtml & EPUB 2 toc.ncx)', () {
      test(
        'EpubEncoder simultaneously generates nav.xhtml (EPUB 3) and toc.ncx (EPUB 2)',
        () {
          final book = Book(
            metadata: const BookMetadata(
              id: 'dual-nav-book',
              title: 'Dual Nav Book',
              language: 'ru',
            ),
            content: const BookContent(
              blocks: [
                BookSection(
                  title: [BookText('Глава 1: Начало')],
                  blocks: [
                    BookParagraph(inlines: [BookText('Текст первой главы')]),
                  ],
                ),
                BookSection(
                  title: [BookText('Глава 2: Развитие')],
                  blocks: [
                    BookParagraph(inlines: [BookText('Текст второй главы')]),
                  ],
                ),
              ],
            ),
            resources: const [],
          );

          final encoder = EpubEncoder();
          final epubBytes = encoder.encode(book);
          final archive = ZipDecoder().decodeBytes(epubBytes);

          // 1. Verify nav.xhtml (EPUB 3) exists in archive and OPF manifest
          final navFile = archive.findFile('OEBPS/nav.xhtml');
          expect(navFile, isNotNull);
          final navContent = utf8.decode(navFile!.content);
          expect(navContent, contains('<nav epub:type="toc" id="toc">'));
          expect(
            navContent,
            contains('<a href="chapter_1.xhtml">Глава 1: Начало</a>'),
          );
          expect(
            navContent,
            contains('<a href="chapter_2.xhtml">Глава 2: Развитие</a>'),
          );

          // 2. Verify toc.ncx (EPUB 2) exists in archive and OPF manifest
          final ncxFile = archive.findFile('OEBPS/toc.ncx');
          expect(ncxFile, isNotNull);
          final ncxContent = utf8.decode(ncxFile!.content);
          expect(
            ncxContent,
            contains('<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"'),
          );
          expect(ncxContent, contains('<text>Глава 1: Начало</text>'));
          expect(ncxContent, contains('<content src="chapter_1.xhtml"/>'));
          expect(ncxContent, contains('<text>Глава 2: Развитие</text>'));
          expect(ncxContent, contains('<content src="chapter_2.xhtml"/>'));

          // 3. Verify content.opf references both
          final opfFile = archive.findFile('OEBPS/content.opf');
          expect(opfFile, isNotNull);
          final opfContent = utf8.decode(opfFile!.content);
          expect(
            opfContent,
            contains(
              '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
            ),
          );
          expect(
            opfContent,
            contains(
              '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
            ),
          );
          expect(opfContent, contains('<spine toc="ncx">'));
        },
      );

      test('EpubNavDocument parses nested TOC and landmarks', () {
        const navHtml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <h1>Оглавление</h1>
      <ol>
        <li>
          <a href="part1.xhtml">Часть 1</a>
          <ol>
            <li><a href="part1_ch1.xhtml">Глава 1.1</a></li>
            <li><a href="part1_ch2.xhtml">Глава 1.2</a></li>
          </ol>
        </li>
        <li><a href="part2.xhtml">Часть 2</a></li>
      </ol>
    </nav>
    <nav epub:type="landmarks">
      <h2>Landmarks</h2>
      <ol>
        <li><a epub:type="cover" href="cover.xhtml">Обложка</a></li>
        <li><a epub:type="bodymatter" href="part1.xhtml">Основной текст</a></li>
      </ol>
    </nav>
  </body>
</html>''';

        final navDoc = EpubNavDocument.parseFromString(navHtml);
        expect(navDoc.toc.length, equals(2));
        expect(navDoc.toc[0].title, equals('Часть 1'));
        expect(navDoc.toc[0].href, equals('part1.xhtml'));
        expect(navDoc.toc[0].children.length, equals(2));
        expect(navDoc.toc[0].children[0].title, equals('Глава 1.1'));
        expect(navDoc.toc[0].children[0].href, equals('part1_ch1.xhtml'));

        expect(navDoc.landmarks.length, equals(2));
        expect(navDoc.landmarks[0].type, equals('cover'));
        expect(navDoc.landmarks[0].href, equals('cover.xhtml'));
        expect(navDoc.landmarks[1].type, equals('bodymatter'));
      });

      test('EpubNcxDocument parses nested navPoints', () {
        const ncxXml = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="uid-123"/></head>
  <docTitle><text>Тестовая книга</text></docTitle>
  <navMap>
    <navPoint id="np-1" playOrder="1">
      <navLabel><text>Раздел 1</text></navLabel>
      <content src="sec1.xhtml"/>
      <navPoint id="np-1-1" playOrder="2">
        <navLabel><text>Подраздел 1.1</text></navLabel>
        <content src="sec1_1.xhtml"/>
      </navPoint>
    </navPoint>
  </navMap>
</ncx>''';

        final ncxDoc = EpubNcxDocument.parseFromString(ncxXml);
        expect(ncxDoc.navMap.length, equals(1));
        expect(ncxDoc.navMap[0].title, equals('Раздел 1'));
        expect(ncxDoc.navMap[0].href, equals('sec1.xhtml'));
        expect(ncxDoc.navMap[0].children.length, equals(1));
        expect(ncxDoc.navMap[0].children[0].title, equals('Подраздел 1.1'));
        expect(ncxDoc.navMap[0].children[0].href, equals('sec1_1.xhtml'));
      });
    });

    // -------------------------------------------------------------------------
    // 4. OPF Metadata (Collections, Layout, ISBN, Publisher, Dates, Source)
    // -------------------------------------------------------------------------
    group(
      'OPF Metadata: belongs-to-collection, rendition:layout, ISBN, publisher, date',
      () {
        test(
          'EpubEncoder & EpubDecoder handle EPUB 3 collections with group-position',
          () async {
            final originalBook = Book(
              metadata: const BookMetadata(
                id: 'series-col-1',
                title: 'Книга из серии',
                language: 'ru',
                series: [
                  BookSeries(name: 'Хроники Дюны', number: 3),
                  BookSeries(name: 'Космическая фантастика', number: 12),
                ],
              ),
              content: const BookContent(
                blocks: [
                  BookSection(
                    title: [BookText('Глава 1')],
                    blocks: [
                      BookParagraph(inlines: [BookText('Текст')]),
                    ],
                  ),
                ],
              ),
              resources: const [],
            );

            final encoder = EpubEncoder();
            final bytes = encoder.encode(originalBook);

            // Verify OPF XML has collection meta properties
            final archive = ZipDecoder().decodeBytes(bytes);
            final opfContent = utf8.decode(
              archive.findFile('OEBPS/content.opf')!.content,
            );

            expect(
              opfContent,
              contains(
                '<meta property="belongs-to-collection" id="series-1">Хроники Дюны</meta>',
              ),
            );
            expect(
              opfContent,
              contains(
                '<meta refines="#series-1" property="group-position">3</meta>',
              ),
            );
            expect(
              opfContent,
              contains(
                '<meta property="belongs-to-collection" id="series-2">Космическая фантастика</meta>',
              ),
            );
            expect(
              opfContent,
              contains(
                '<meta refines="#series-2" property="group-position">12</meta>',
              ),
            );

            // Decode and verify BookSeries reconstruction
            final decodedBook = await EpubDecoder().decode(bytes);
            expect(decodedBook.metadata.series.length, equals(2));
            expect(decodedBook.metadata.series[0].name, equals('Хроники Дюны'));
            expect(decodedBook.metadata.series[0].number, equals(3));
            expect(
              decodedBook.metadata.series[1].name,
              equals('Космическая фантастика'),
            );
            expect(decodedBook.metadata.series[1].number, equals(12));
          },
        );

        test(
          'EpubEncoder & EpubDecoder handle Rendition Layout (pre-paginated & roll)',
          () async {
            // 1. Fixed Layout (pre-paginated)
            final fixedBook = Book(
              metadata: const BookMetadata(
                id: 'fixed-1',
                title: 'Fixed Layout Book',
                language: 'en',
                layout: BookLayout.fixedLayout,
              ),
              content: const BookContent(
                blocks: [
                  BookParagraph(inlines: [BookText('Page 1')]),
                ],
              ),
              resources: const [],
            );
            final fixedBytes = EpubEncoder().encode(fixedBook);
            final fixedArchive = ZipDecoder().decodeBytes(fixedBytes);
            final fixedOpf = utf8.decode(
              fixedArchive.findFile('OEBPS/content.opf')!.content,
            );
            expect(
              fixedOpf,
              contains(
                '<meta property="rendition:layout">pre-paginated</meta>',
              ),
            );

            final decodedFixed = await EpubDecoder().decode(fixedBytes);
            expect(
              decodedFixed.metadata.layout,
              equals(BookLayout.fixedLayout),
            );

            // 2. Roll layout
            final rollBook = Book(
              metadata: const BookMetadata(
                id: 'roll-1',
                title: 'Roll Layout Book',
                language: 'en',
                layout: BookLayout.roll,
              ),
              content: const BookContent(
                blocks: [
                  BookParagraph(inlines: [BookText('Webtoon scroll')]),
                ],
              ),
              resources: const [],
            );
            final rollBytes = EpubEncoder().encode(rollBook);
            final rollArchive = ZipDecoder().decodeBytes(rollBytes);
            final rollOpf = utf8.decode(
              rollArchive.findFile('OEBPS/content.opf')!.content,
            );
            expect(
              rollOpf,
              contains('<meta property="rendition:layout">roll</meta>'),
            );

            final decodedRoll = await EpubDecoder().decode(rollBytes);
            expect(decodedRoll.metadata.layout, equals(BookLayout.roll));
          },
        );

        test(
          'EpubEncoder & EpubDecoder handle ISBN URN, dc:publisher, dc:date, source-language, dc:source',
          () async {
            final originalBook = Book(
              metadata: BookMetadata(
                id: 'meta-full-epub',
                title: 'Полные Метаданные EPUB',
                language: 'ru',
                srcLang: 'de',
                publishedAt: DateTime(2023, 10, 25),
                publishInfo: const BookPublishInfo(
                  publisher: 'Манн, Иванов и Фербер',
                  isbn: '978-5-00195-123-4',
                  year: 2023,
                ),
                srcTitleInfo: const BookSourceTitleInfo(
                  title: 'Das Originalbuch',
                ),
              ),
              content: const BookContent(
                blocks: [
                  BookSection(
                    title: [BookText('Введение')],
                    blocks: [
                      BookParagraph(inlines: [BookText('Текст введения')]),
                    ],
                  ),
                ],
              ),
              resources: const [],
            );

            final bytes = EpubEncoder().encode(originalBook);
            final archive = ZipDecoder().decodeBytes(bytes);
            final opfContent = utf8.decode(
              archive.findFile('OEBPS/content.opf')!.content,
            );

            // Verify XML tags
            expect(
              opfContent,
              contains(
                '<dc:identifier id="pub-isbn">urn:isbn:978-5-00195-123-4</dc:identifier>',
              ),
            );
            expect(
              opfContent,
              contains('<dc:publisher>Манн, Иванов и Фербер</dc:publisher>'),
            );
            expect(opfContent, contains('<dc:date>2023-10-25</dc:date>'));
            expect(
              opfContent,
              contains('<meta property="source-language">de</meta>'),
            );
            expect(
              opfContent,
              contains('<dc:source>Das Originalbuch</dc:source>'),
            );

            // Decode and verify properties
            final decodedBook = await EpubDecoder().decode(bytes);
            expect(
              decodedBook.metadata.publishInfo?.publisher,
              equals('Манн, Иванов и Фербер'),
            );
            expect(
              decodedBook.metadata.publishInfo?.isbn,
              equals('978-5-00195-123-4'),
            );
            expect(
              decodedBook.metadata.publishedAt,
              equals(DateTime(2023, 10, 25)),
            );
            expect(decodedBook.metadata.srcLang, equals('de'));
            expect(
              decodedBook.metadata.srcTitleInfo?.title,
              equals('Das Originalbuch'),
            );
          },
        );
      },
    );

    // -------------------------------------------------------------------------
    // 5. Exceptions & Error Handling
    // -------------------------------------------------------------------------
    group(
      'Exceptions: EpubEncryptedResourceException, EpubInvalidPackageException, Strict Mode',
      () {
        test(
          'Throws EpubEncryptedResourceException on actual DRM encrypted content',
          () async {
            final archive = Archive();
            archive.addFile(
              ArchiveFile.noCompress(
                'mimetype',
                20,
                utf8.encode('application/epub+zip'),
              ),
            );
            archive.addFile(
              ArchiveFile(
                'META-INF/container.xml',
                180,
                utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
              ),
            );
            // encryption.xml with AES-128 DRM encryption
            archive.addFile(
              ArchiveFile(
                'META-INF/encryption.xml',
                300,
                utf8.encode('''<?xml version="1.0"?>
<encryption xmlns="http://www.w3.org/2001/04/xmlenc#">
  <EncryptedData>
    <EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>
    <CipherData><CipherReference URI="OEBPS/chapter1.xhtml"/></CipherData>
  </EncryptedData>
</encryption>'''),
              ),
            );
            archive.addFile(
              ArchiveFile(
                'OEBPS/content.opf',
                300,
                utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>DRM Book</dc:title><dc:language>en</dc:language></metadata>
  <manifest><item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
              ),
            );

            final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
            final decoder = EpubDecoder();

            expect(
              () => decoder.decode(zipBytes),
              throwsA(
                isA<EpubEncryptedResourceException>().having(
                  (e) => e.encryptedPaths,
                  'encryptedPaths',
                  contains('OEBPS/chapter1.xhtml'),
                ),
              ),
            );
          },
        );

        test(
          'Throws EpubInvalidPackageException when META-INF/container.xml is missing or has no rootfiles',
          () {
            // 1. Missing container.xml
            final archiveWithoutContainer = Archive();
            archiveWithoutContainer.addFile(
              ArchiveFile.noCompress(
                'mimetype',
                20,
                utf8.encode('application/epub+zip'),
              ),
            );
            final zip1 = Uint8List.fromList(
              ZipEncoder().encode(archiveWithoutContainer),
            );

            expect(
              () => EpubDecoder().decode(zip1),
              throwsA(isA<EpubInvalidPackageException>()),
            );

            // 2. container.xml with no rootfile
            final archiveEmptyContainer = Archive();
            archiveEmptyContainer.addFile(
              ArchiveFile.noCompress(
                'mimetype',
                20,
                utf8.encode('application/epub+zip'),
              ),
            );
            archiveEmptyContainer.addFile(
              ArchiveFile(
                'META-INF/container.xml',
                100,
                utf8.encode(
                  '<?xml version="1.0"?><container version="1.0"><rootfiles></rootfiles></container>',
                ),
              ),
            );
            final zip2 = Uint8List.fromList(
              ZipEncoder().encode(archiveEmptyContainer),
            );

            expect(
              () => EpubDecoder().decode(zip2),
              throwsA(isA<EpubInvalidPackageException>()),
            );
          },
        );

        test(
          'Throws BookMalformedMetadataException in strictMode when dc:title is missing',
          () async {
            final archive = Archive();
            archive.addFile(
              ArchiveFile.noCompress(
                'mimetype',
                20,
                utf8.encode('application/epub+zip'),
              ),
            );
            archive.addFile(
              ArchiveFile(
                'META-INF/container.xml',
                180,
                utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''),
              ),
            );
            // OPF with missing dc:title
            archive.addFile(
              ArchiveFile(
                'OEBPS/content.opf',
                300,
                utf8.encode('''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uid" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">id-123</dc:identifier>
    <dc:language>en</dc:language>
  </metadata>
  <manifest><item id="ch1" href="chap1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>'''),
              ),
            );
            archive.addFile(
              ArchiveFile(
                'OEBPS/chap1.xhtml',
                50,
                utf8.encode('<html><body><p>Hi</p></body></html>'),
              ),
            );

            final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
            final decoder = EpubDecoder();

            expect(
              () => decoder.decode(
                zipBytes,
                options: const BookDecodingOptions(strictMode: true),
              ),
              throwsA(isA<BookMalformedMetadataException>()),
            );
          },
        );
      },
    );

    // -------------------------------------------------------------------------
    // 6. Comprehensive AST Roundtrip Integration
    // -------------------------------------------------------------------------
    group(
      'Comprehensive AST Roundtrip with GoldenComparator and AstNormalizer',
      () {
        test(
          'Full roundtrip conversion of rich AST structures through EPUB',
          () async {
            final originalBook = Book(
              metadata: BookMetadata(
                id: 'epub-rich-rt-1',
                title: 'Полный Тест EPUB',
                language: 'ru',
                contributors: [
                  const BookContributor(
                    role: BookContributorRole.author,
                    name: PersonName(
                      first: 'Лев',
                      last: 'Толстой',
                      display: 'Лев Толстой',
                    ),
                  ),
                ],
                publishInfo: const BookPublishInfo(
                  publisher: 'Классика',
                  year: 2024,
                ),
              ),
              content: const BookContent(
                blocks: [
                  BookSection(
                    id: 'chapter_1',
                    title: [BookText('Глава 1: Начало')],
                    blocks: [
                      BookHeading(level: 2, text: [BookText('Подзаголовок')]),
                      BookParagraph(
                        inlines: [
                          BookText('Текст с '),
                          BookStrong(children: [BookText('полужирным')]),
                          BookText(', '),
                          BookEmphasis(children: [BookText('курсивом')]),
                          BookText(', '),
                          BookStrike(children: [BookText('зачеркиванием')]),
                          BookText(', '),
                          BookCodeSpan('const value = 42;'),
                          BookText(' и сноской '),
                          BookFootnoteRef(id: 'fn-1', label: [BookText('[1]')]),
                          BookText('.'),
                        ],
                      ),
                      BookQuote(
                        blocks: [
                          BookParagraph(inlines: [BookText('Цитата классика')]),
                        ],
                        citation: [BookText('Толстой')],
                      ),
                      BookList(
                        ordered: false,
                        items: [
                          BookListItem(
                            blocks: [
                              BookParagraph(inlines: [BookText('Пункт 1')]),
                            ],
                          ),
                          BookListItem(
                            blocks: [
                              BookParagraph(inlines: [BookText('Пункт 2')]),
                            ],
                          ),
                        ],
                      ),
                      BookTable(
                        rows: [
                          BookTableRow(
                            cells: [
                              BookTableCell(
                                blocks: [
                                  BookParagraph(
                                    inlines: [BookText('Заголовок')],
                                  ),
                                ],
                                colSpan: 2,
                              ),
                            ],
                          ),
                          BookTableRow(
                            cells: [
                              BookTableCell(
                                blocks: [
                                  BookParagraph(inlines: [BookText('1.1')]),
                                ],
                              ),
                              BookTableCell(
                                blocks: [
                                  BookParagraph(inlines: [BookText('1.2')]),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      BookCodeBlock(code: 'void main() => print("EPUB");'),
                      BookImageBlock(
                        id: 'img1',
                        ref: BookResourceRef('picture.png'),
                        alt: 'Картинка',
                        title: 'Подпись',
                      ),
                      BookAudioBlock(
                        ref: BookResourceRef('sound.mp3'),
                        controls: true,
                      ),
                      BookVideoBlock(
                        ref: BookResourceRef('video.mp4'),
                        controls: true,
                      ),
                      BookMathBlock(mathml: '<math><mi>x</mi></math>'),
                      BookSvgBlock(
                        svg: '<svg><rect width="10" height="10"/></svg>',
                      ),
                      BookHorizontalRule(),
                    ],
                  ),
                ],
              ),
              resources: [
                BookResource(
                  id: 'picture.png',
                  mediaType: 'image/png',
                  bytes: Uint8List.fromList([1, 2, 3]),
                ),
                BookResource(
                  id: 'sound.mp3',
                  mediaType: 'audio/mpeg',
                  bytes: Uint8List.fromList([4, 5, 6]),
                ),
                BookResource(
                  id: 'video.mp4',
                  mediaType: 'video/mp4',
                  bytes: Uint8List.fromList([7, 8, 9]),
                ),
              ],
            );

            final epubBytes = await EpubConverter.bookToEpub(originalBook);
            expect(epubBytes, isNotEmpty);

            final decodedBook = await EpubConverter.epubToBook(epubBytes);
            expect(
              decodedBook.metadata.title,
              equals(originalBook.metadata.title),
            );
            expect(
              decodedBook.metadata.language,
              equals(originalBook.metadata.language),
            );
            expect(
              decodedBook.resources.length,
              equals(originalBook.resources.length),
            );

            // Verify decoded section and its inner blocks
            expect(decodedBook.content.blocks.length, equals(1));
            final section = decodedBook.content.blocks.first as BookSection;
            expect(section.title.first, isA<BookText>());
            expect(
              (section.title.first as BookText).text,
              equals('Глава 1: Начало'),
            );

            final blocks = section.blocks;
            expect(blocks[0], isA<BookHeading>());
            expect(blocks[1], isA<BookParagraph>());
            expect(blocks[2], isA<BookQuote>());
            expect(blocks[3], isA<BookList>());
            expect(blocks[4], isA<BookTable>());
            expect(blocks[5], isA<BookCodeBlock>());
            expect(
              (blocks[5] as BookCodeBlock).code,
              equals('void main() => print("EPUB");'),
            );
            expect(blocks[6], isA<BookImageBlock>());
            expect(
              (blocks[6] as BookImageBlock).ref.id,
              equals('epub-res-picture.png'),
            );
            expect(blocks[7], isA<BookAudioBlock>());
            expect(blocks[8], isA<BookVideoBlock>());
            expect(blocks[9], isA<BookMathBlock>());
            expect(blocks[10], isA<BookSvgBlock>());
            expect(blocks[11], isA<BookHorizontalRule>());

            // Verify paragraph inlines
            final p = blocks[1] as BookParagraph;
            expect(p.inlines.any((i) => i is BookStrong), isTrue);
            expect(p.inlines.any((i) => i is BookEmphasis), isTrue);
            expect(p.inlines.any((i) => i is BookStrike), isTrue);
            expect(p.inlines.any((i) => i is BookCodeSpan), isTrue);
            expect(p.inlines.any((i) => i is BookFootnoteRef), isTrue);

            // Verify normalized AST identity with AstNormalizer and GoldenComparator
            final textOnlyBook = Book(
              metadata: const BookMetadata(
                id: 'norm-epub-1',
                title: 'Norm Test',
                language: 'ru',
              ),
              content: const BookContent(
                blocks: [
                  BookSection(
                    id: 'chapter_1',
                    title: [BookText('Глава 1')],
                    blocks: [
                      BookHeading(level: 2, text: [BookText('Заголовок')]),
                      BookParagraph(inlines: [BookText('Параграф один')]),
                      BookQuote(
                        blocks: [
                          BookParagraph(inlines: [BookText('Цитата')]),
                        ],
                        citation: [BookText('Автор')],
                      ),
                    ],
                  ),
                ],
              ),
              resources: const [],
            );

            final textEpubBytes = await EpubConverter.bookToEpub(textOnlyBook);
            final decodedTextBook = await EpubConverter.epubToBook(
              textEpubBytes,
            );
            final normDecoded = AstNormalizer.normalizeBook(decodedTextBook);
            final normOriginal = AstNormalizer.normalizeBook(textOnlyBook);
            GoldenComparator.assertContentEquals(
              normDecoded.content,
              normOriginal.content,
            );
          },
        );
      },
    );
  });
}
