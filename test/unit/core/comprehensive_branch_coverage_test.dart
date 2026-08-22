import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  group('Comprehensive Branch Coverage & Edge Case Tests', () {
    test(
      'DartBook facade handles resourceResolver and unknown formats/encoders',
      () async {
        // Unknown decoder format throws Exception
        final invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4]);
        expect(
          () => DartBook.load(invalidBytes, filename: 'unknown.xyz'),
          throwsA(isA<Exception>()),
        );

        // Unknown encoder in isolate throws Exception
        const dummyBook = Book(
          metadata: BookMetadata(id: '1', title: 'T', language: 'ru'),
          content: BookContent(blocks: []),
          resources: [],
        );
        expect(
          () => DartBook.encodeIsolated(dummyBook, 'xyz'),
          throwsA(isA<Exception>()),
        );

        // DartBook.load with resourceResolver
        final fb2Xml = utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <genre>fiction</genre>
      <author><first-name>Иван</first-name><last-name>Иванов</last-name></author>
      <book-title>Тестовая книга</book-title>
      <lang>ru</lang>
      <coverpage><image l:href="#cover.png"/></coverpage>
    </title-info>
    <src-title-info>
      <genre>fiction</genre>
      <author><nickname>OriginalNick</nickname></author>
      <book-title>Original Title</book-title>
      <lang>en</lang>
    </src-title-info>
    <document-info>
      <author><nickname>DocAuthor</nickname></author>
      <program>DartBook</program>
      <date value="2026-01-01">2026</date>
      <id>doc-123</id>
      <version>1.0</version>
    </document-info>
    <publish-info>
      <publisher>Эксмо</publisher>
      <city>Москва</city>
      <year>2026</year>
      <isbn>978-5-00-000000-0</isbn>
    </publish-info>
    <custom-info info-type="sequence-url">https://example.com/series/1</custom-info>
  </description>
  <body>
    <section>
      <title><p>Глава 1</p></title>
      <epigraph><p>Эпиграф к главе</p><text-author>Автор эпиграфа</text-author></epigraph>
      <p>Текст с <style name="lead">кастомным стилем</style>.</p>
    </section>
  </body>
</FictionBook>''');

        final loadedBook = await DartBook.load(
          Uint8List.fromList(fb2Xml),
          filename: 'book.fb2',
          resourceResolver: (req, {onByteProgress}) async {
            if (req.id == 'cover.png') {
              return BookResource(
                id: 'cover.png',
                mediaType: 'image/png',
                bytes: Uint8List.fromList([1, 2, 3]),
              );
            }
            return null;
          },
        );

        expect(loadedBook.resources.length, equals(1));
        expect(
          loadedBook.metadata.srcTitleInfo?.title,
          equals('Original Title'),
        );
        expect(loadedBook.metadata.publishInfo?.city, equals('Москва'));
        expect(
          loadedBook.metadata.primarySeries?.url,
          equals(Uri.parse('https://example.com/series/1')),
        );

        expect(
          loadedBook.metadata.contributorsByRole(BookContributorRole.author),
          isNotEmpty,
        );
      },
    );

    test(
      'BookConverter class instances (EpubConverter, Fb2Converter, Fb2ZipConverter)',
      () async {
        final epubConverter = EpubConverter();
        final fb2Converter = Fb2Converter();
        final fb2ZipConverter = Fb2ZipConverter();

        expect(epubConverter.canEncode('epub'), isTrue);
        expect(epubConverter.canEncode('fb2'), isFalse);
        expect(fb2Converter.canEncode('fb2'), isTrue);
        expect(fb2Converter.canEncode('xml'), isTrue);
        expect(fb2ZipConverter.canEncode('fb2.zip'), isTrue);

        final dummyBook = const Book(
          metadata: BookMetadata(
            id: 'c1',
            title: 'Converter Book',
            language: 'ru',
          ),
          content: BookContent(
            blocks: [
              BookParagraph(inlines: [BookText('Hi')]),
            ],
          ),
          resources: [],
        );

        // Polymorphic encode/decode
        final epubBytes = await epubConverter.encode(dummyBook);
        expect(epubConverter.canDecode(epubBytes, extension: 'epub'), isTrue);
        final decodedEpub = await epubConverter.decode(epubBytes);
        expect(decodedEpub.metadata.title, equals('Converter Book'));

        final fb2Bytes = await fb2Converter.encode(dummyBook);
        expect(fb2Converter.canDecode(fb2Bytes, extension: 'fb2'), isTrue);
        final decodedFb2 = await fb2Converter.decode(fb2Bytes);
        expect(decodedFb2.metadata.title, equals('Converter Book'));

        final fb2ZipBytes = await fb2ZipConverter.encode(dummyBook);
        expect(
          fb2ZipConverter.canDecode(fb2ZipBytes, extension: 'fb2.zip'),
          isTrue,
        );
        final decodedFb2Zip = fb2ZipConverter.decode(fb2ZipBytes);
        expect(decodedFb2Zip.metadata.title, equals('Converter Book'));

        // Static direct bookToFb2Zip
        final zipDirect = await Fb2ZipConverter.bookToFb2Zip(dummyBook);
        expect(zipDirect, isNotEmpty);
        final unzippedBook = Fb2ZipConverter.fb2ZipToBook(zipDirect);
        expect(unzippedBook.metadata.title, equals('Converter Book'));
      },
    );

    test('BookRegistry dynamic decoder and encoder registration', () {
      final customDecoder = _DummyDecoder();
      final customEncoder = _DummyEncoder();

      BookRegistry.registerDecoder(customDecoder);
      BookRegistry.registerEncoder(customEncoder);

      expect(
        BookRegistry.findDecoder(
          Uint8List.fromList([99, 99]),
          extension: 'dummy',
        ),
        isNotNull,
      );
      expect(BookRegistry.findEncoder('dummy'), isNotNull);
      expect(BookRegistry.findEncoder('.dummy'), isNotNull);
    });

    test('Exceptions toString() formatting', () {
      const ex1 = BookFormatException('Format error');
      expect(ex1.toString(), contains('BookFormatException: Format error'));

      const ex2 = BookParseException('Parse failed', line: 42, tag: 'body');
      expect(
        ex2.toString(),
        contains('BookParseException: Parse failed (tag: <body>, line: 42)'),
      );

      const ex3 = BookMalformedMetadataException('Bad metadata');
      expect(
        ex3.toString(),
        contains('BookMalformedMetadataException: Bad metadata'),
      );
    });

    test('ResourceRequestsCollector covers all inline and block variants', () {
      final richBook = Book(
        metadata: const BookMetadata(
          id: 'req-full',
          title: 'Requests',
          language: 'ru',
        ),
        content: const BookContent(
          blocks: [
            BookHeading(
              level: 2,
              text: [
                BookStrike(
                  children: [
                    BookSuperscript(
                      children: [
                        BookSubscript(
                          children: [
                            BookImageInline(
                              ref: BookResourceRef('nested_inline.png'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                BookFootnoteRef(
                  id: 'fn_1',
                  label: [
                    BookImageInline(ref: BookResourceRef('fn_label_img.png')),
                  ],
                ),
              ],
            ),
          ],
        ),
        resources: const [],
      );

      final reqs = collectResourceRequestsFromBook(richBook);
      final reqIds = reqs.map((r) => r.id).toList();
      expect(reqIds, contains('nested_inline.png'));
      expect(reqIds, contains('fn_label_img.png'));
    });

    test(
      'Fb2Encoder and EpubEncoder serialize Raw HTML and Raw XML inlines',
      () async {
        final rawBook = const Book(
          metadata: BookMetadata(
            id: 'raw-book',
            title: 'Raw Book',
            language: 'en',
          ),
          content: BookContent(
            blocks: [
              BookParagraph(
                inlines: [
                  BookText('Текст с '),
                  BookRawHtmlInline('<b>сырым HTML</b>'),
                  BookText(' и '),
                  BookRawXmlInline('<custom-elem>сырым XML</custom-elem>'),
                ],
              ),
            ],
          ),
          resources: [],
        );

        final fb2Bytes = await Fb2Converter.bookToFb2(rawBook);
        final fb2Str = utf8.decode(fb2Bytes);
        expect(fb2Str, contains('сырым HTML'));
        expect(fb2Str, contains('сырым XML'));

        final epubBytes = await EpubConverter.bookToEpub(rawBook);
        expect(epubBytes, isNotEmpty);
      },
    );

    test('ResourceNamingPolicy covers all extension deduction branches', () {
      const policy = BookResourceNamingPolicy.preserve;

      expect(
        policy.generateName(
          'http://site.com/pic.svg',
          isInline: false,
          index: 1,
        ),
        equals('pic.svg'),
      );
      expect(
        policy.generateName(
          'http://site.com/audio.mp3',
          isInline: false,
          index: 2,
        ),
        equals('audio.mp3'),
      );
      expect(
        policy.generateName(
          'http://site.com/video.mp4',
          isInline: false,
          index: 3,
        ),
        equals('video.mp4'),
      );
      expect(
        policy.generateName(
          'http://site.com/track.opus',
          isInline: false,
          index: 4,
        ),
        equals('track.opus'),
      );
      expect(
        policy.generateName(
          'http://site.com/font.woff2',
          isInline: false,
          index: 5,
        ),
        equals('font.woff2'),
      );

      // Data URIs for diverse mime types
      expect(
        policy.generateName(
          'data:image/gif;base64,R0lGOD...',
          isInline: false,
          index: 6,
        ),
        equals('img_006.gif'),
      );
      expect(
        policy.generateName(
          'data:image/webp;base64,UklGR...',
          isInline: false,
          index: 7,
        ),
        equals('img_007.webp'),
      );
      expect(
        policy.generateName(
          'data:image/svg+xml;base64,...',
          isInline: false,
          index: 8,
        ),
        equals('img_008.svg'),
      );
      expect(
        policy.generateName(
          'data:image/avif;base64,...',
          isInline: false,
          index: 9,
        ),
        equals('img_009.avif'),
      );
      expect(
        policy.generateName(
          'data:image/jxl;base64,...',
          isInline: false,
          index: 10,
        ),
        equals('img_010.jxl'),
      );
      expect(
        policy.generateName(
          'data:application/octet-stream;base64,...',
          isInline: false,
          index: 11,
        ),
        equals('img_011.png'),
      );
    });

    test(
      'Fb2Converter and Fb2ZipConverter helper static methods with options and resolvers',
      () async {
        final book = const Book(
          metadata: BookMetadata(
            id: 'z-book',
            title: 'Zip Book',
            language: 'ru',
          ),
          content: BookContent(
            blocks: [
              BookParagraph(inlines: [BookText('Content')]),
            ],
          ),
          resources: [],
        );

        final zip1 = await Fb2Converter.bookToFb2(
          book,
          isZip: true,
          resourceResolver: (req, {onByteProgress}) async => null,
        );
        expect(zip1, isNotEmpty);

        final zip2 = await Fb2ZipConverter.bookToFb2Zip(
          book,
          resourceResolver: (req, {onByteProgress}) async => null,
        );
        expect(zip2, isNotEmpty);

        final decoded = Fb2ZipConverter.fb2ZipToBook(zip2);
        expect(decoded.metadata.title, equals('Zip Book'));
      },
    );

    test(
      'Fb2Decoder edge cases: middle-name, nickname only, flat footnotes, malformed base64',
      () {
        final fb2Xml = utf8.encode('''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <genre>prose</genre>
      <author>
        <first-name>Лев</first-name>
        <middle-name>Николаевич</middle-name>
        <last-name>Толстой</last-name>
      </author>
      <author>
        <nickname>AnonCoder</nickname>
      </author>
      <book-title>Книга с полным именем</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <section><p>Текст</p></section>
  </body>
  <body name="notes">
    <p>Прямой параграф сноски без section</p>
  </body>
  <binary id="b1.png" content-type="image/png">
    A
  </binary>
  <binary id="b2.png" content-type="image/png">
    %%%invalid_base64%%%
  </binary>
</FictionBook>''');

        final book = Fb2Decoder().decode(Uint8List.fromList(fb2Xml));
        expect(book.metadata.contributors.length, equals(2));
        expect(
          book.metadata.contributors[0].name.display,
          equals('Лев Николаевич Толстой'),
        );
        expect(book.metadata.contributors[1].name.display, equals('AnonCoder'));
        expect(book.content.footnotes.length, equals(1));
        expect(book.content.footnotes.first.id, equals('notes'));
      },
    );

    test('OcfContainer error handling and DRM paths parsing', () {
      final emptyArchive = Archive();
      expect(
        () => OcfContainer.fromArchive(emptyArchive),
        throwsA(isA<EpubInvalidPackageException>()),
      );

      const emptyContainer = OcfContainer(rootfiles: []);
      expect(
        () => emptyContainer.primaryOpfPath,
        throwsA(isA<EpubInvalidPackageException>()),
      );

      final encArchive = Archive();
      const encXml = '''<?xml version="1.0" encoding="UTF-8"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <EncryptedData>
    <EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>
    <CipherData>
      <CipherReference URI="secret.xhtml"/>
    </CipherData>
  </EncryptedData>
</encryption>''';
      final encBytes = utf8.encode(encXml);
      encArchive.addFile(
        ArchiveFile('META-INF/encryption.xml', encBytes.length, encBytes),
      );

      final drmPaths = OcfContainer.parseEncryptionPaths(encArchive);
      expect(drmPaths, contains('secret.xhtml'));
    });

    test(
      'Fb2Decoder strictMode exceptions, logger integration, and canDecode ZIP check',
      () {
        final decoder = Fb2Decoder();
        // ZIP bytes should not be decoded by raw Fb2Decoder
        final zipHeader = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0]);
        expect(decoder.canDecode(zipHeader), isFalse);

        // Strict mode: XML parse error
        const badSyntaxXml = '<?xml version="1.0"?><FictionBook><unclosed>';
        expect(
          () => decoder.decode(
            Uint8List.fromList(utf8.encode(badSyntaxXml)),
            options: const BookDecodingOptions(strictMode: true),
          ),
          throwsA(isA<BookParseException>()),
        );

        // Strict mode: Missing description element
        const noDescXml =
            '<?xml version="1.0"?><FictionBook><body><section><p>Hi</p></section></body></FictionBook>';
        expect(
          () => decoder.decode(
            Uint8List.fromList(utf8.encode(noDescXml)),
            options: const BookDecodingOptions(strictMode: true),
          ),
          throwsA(isA<BookMalformedMetadataException>()),
        );

        // Non-strict mode: Logger integration on unparseable XML
        var logCalled = false;
        const totallyCorruptXml = '<<<not valid xml at all>>>';
        expect(
          () => decoder.decode(
            Uint8List.fromList(utf8.encode(totallyCorruptXml)),
            options: BookDecodingOptions(
              strictMode: false,
              logger: (msg) => logCalled = true,
            ),
          ),
          throwsA(isA<BookFormatException>()),
        );
        expect(logCalled, isTrue);
      },
    );

    test('EpubNcxDocument handles missing navMap element', () {
      const ncxNoNavMap = '<?xml version="1.0"?><ncx><head></head></ncx>';
      final doc = EpubNcxDocument.parseFromString(ncxNoNavMap);
      expect(doc.navMap, isEmpty);
    });
  });
}

class _DummyDecoder implements BookDecoder {
  @override
  bool canDecode(Uint8List bytes, {String? extension}) => extension == 'dummy';

  @override
  Book decode(Uint8List bytes, {BookDecodingOptions? options}) => const Book(
    metadata: BookMetadata(id: 'd', title: 'Dummy', language: 'en'),
    content: BookContent(blocks: []),
    resources: [],
  );
}

class _DummyEncoder implements BookEncoder {
  @override
  bool canEncode(String extension) => extension == 'dummy';

  @override
  Uint8List encode(Book book, {BookEncodingOptions? options}) => Uint8List(0);
}
