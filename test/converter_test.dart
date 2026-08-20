import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_book/dart_book.dart';
import 'package:test/test.dart';

void main() {
  final sampleBook = Book(
    metadata: const BookMetadata(
      id: 'test-book-1',
      title: 'Test Book Title',
      language: 'ru',
      contributors: [
        BookContributor(
          role: BookContributorRole.author,
          name: PersonName(first: 'Антон', last: 'Чехов', display: 'Антон Чехов'),
        ),
      ],
      genres: [BookGenre(code: 'prose_classic', name: 'Классика')],
      cover: BookCover(ref: BookResourceRef('cover.jpg')),
    ),
    content: const BookContent(
      blocks: [
        BookHeading(level: 1, text: [BookText('Глава 1')]),
        BookParagraph(inlines: [
          BookText('Это '),
          BookStrong(children: [BookText('важный')]),
          BookText(' текст с '),
          BookCodeSpan('var x = 42;'),
          BookText('.'),
        ]),
        BookQuote(
          blocks: [BookParagraph(inlines: [BookText('Краткость — сестра таланта.')])],
          citation: [BookText('А.П. Чехов')],
        ),
        BookList(
          ordered: false,
          items: [
            BookListItem(blocks: [BookParagraph(inlines: [BookText('Пункт 1')])]),
            BookListItem(blocks: [BookParagraph(inlines: [BookText('Пункт 2')])]),
          ],
        ),
      ],
    ),
    resources: [
      BookResource(
        id: 'cover.jpg',
        mediaType: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      ),
      BookResource(
        id: 'audio1.mp3',
        mediaType: 'audio/mpeg',
        bytes: Uint8List.fromList([10, 20, 30]),
      ),
    ],
  );

  group('FB2 Converter Tests', () {
    test('Encodes and decodes FB2 maintaining metadata and content', () async {
      final bytes = await Fb2Converter.bookToFb2(sampleBook);
      expect(bytes, isNotEmpty);

      final xmlString = String.fromCharCodes(bytes);
      expect(xmlString, contains('<code>var x = 42;</code>'));

      final decoded = Fb2Converter.fb2ToBook(bytes);
      expect(decoded.metadata.title, equals('Test Book Title'));
      expect(decoded.metadata.language, equals('ru'));
      expect(decoded.metadata.contributors.length, equals(1));
      expect(decoded.metadata.contributors.first.name.display, equals('Антон Чехов'));
      expect(decoded.resources.length, equals(2));
      expect(decoded.resources.first.id, equals('cover.jpg'));
      expect(decoded.resources.first.bytes, equals([1, 2, 3, 4, 5]));
      expect(decoded.metadata.cover, isNotNull);
      expect(decoded.metadata.cover!.ref.id, equals('cover.jpg'));
    });
  });

  group('EPUB Converter Tests', () {
    test('Encodes and decodes EPUB maintaining metadata, cover, audio and content', () async {
      final bytes = await EpubConverter.bookToEpub(sampleBook);
      expect(bytes, isNotEmpty);

      final decoded = await EpubConverter.epubToBook(bytes);
      expect(decoded.metadata.id, equals('test-book-1'));
      expect(decoded.metadata.title, equals('Test Book Title'));
      expect(decoded.metadata.language, equals('ru'));
      expect(decoded.metadata.contributors.length, equals(1));
      expect(decoded.resources.length, equals(2));
      expect(decoded.metadata.cover, isNotNull);

      // Verify audio extraction in resources
      final audioRes = decoded.resources.firstWhere((r) => r.mediaType == 'audio/mpeg');
      expect(audioRes.bytes, equals([10, 20, 30]));
    });

    test('EpubException extends BookException', () {
      final exc = EpubInvalidPackageException('Corrupt OPF');
      expect(exc, isA<BookException>());
      expect(exc, isA<EpubException>());
    });

    test('Generates dual navigation nav.xhtml and toc.ncx in EPUB', () async {
      final bytes = await EpubConverter.bookToEpub(sampleBook);
      expect(bytes, isNotEmpty);

      // Verify that toc.ncx is generated
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('OEBPS/toc.ncx'), isNotNull);
      expect(archive.findFile('OEBPS/nav.xhtml'), isNotNull);
      final opf = String.fromCharCodes(archive.findFile('OEBPS/content.opf')!.content);
      expect(opf, contains('toc="ncx"'));
      expect(opf, contains('href="toc.ncx"'));
    });

    test('Font deobfuscation works for IDPF and Adobe algorithms', () {
      const uid = 'urn:uuid:12345678-1234-1234-1234-123456789abc';
      final originalBytes = Uint8List.fromList(List.generate(2000, (i) => i % 256));

      // Obfuscate with IDPF
      final obfuscatedIdpf = OcfContainer.deobfuscateFont(
        originalBytes,
        'http://www.idpf.org/2008/embedding',
        uid,
      );
      expect(obfuscatedIdpf, isNot(equals(originalBytes)));

      // Deobfuscate with IDPF (XOR symmetry)
      final restoredIdpf = OcfContainer.deobfuscateFont(
        obfuscatedIdpf,
        'http://www.idpf.org/2008/embedding',
        uid,
      );
      expect(restoredIdpf, equals(originalBytes));

      // Obfuscate and deobfuscate with Adobe
      final obfuscatedAdobe = OcfContainer.deobfuscateFont(
        originalBytes,
        'http://ns.adobe.com/pdf/enc#RC',
        uid,
      );
      final restoredAdobe = OcfContainer.deobfuscateFont(
        obfuscatedAdobe,
        'http://ns.adobe.com/pdf/enc#RC',
        uid,
      );
      expect(restoredAdobe, equals(originalBytes));
    });

    test('Encodes and decodes FB2 footnotes, epigraphs, tables and translators', () async {
      final richBook = Book(
        metadata: BookMetadata(
          id: 'rich-book-1',
          title: 'Rich Book',
          language: 'ru',
          publishedAt: DateTime(2023, 5, 12),
          contributors: [
            BookContributor(
              role: BookContributorRole.author,
              name: const PersonName(first: 'Лев', last: 'Толстой', display: 'Лев Толстой'),
              email: 'leo@tolstoy.ru',
              homePage: Uri.parse('https://tolstoy.ru'),
            ),
            BookContributor(
              role: BookContributorRole.translator,
              name: const PersonName(first: 'John', last: 'Smith', display: 'John Smith'),
            ),
          ],
        ),
        content: const BookContent(
          blocks: [
            BookQuote(
              blocks: [BookParagraph(inlines: [BookText('Эпиграф книги')])],
              citation: [BookText('Народная мудрость')],
              attributes: {'fb2-type': 'epigraph'},
            ),
            BookParagraph(inlines: [
              BookText('Параграф со сноской'),
              BookFootnoteRef(id: 'note_1', label: [BookText('1')]),
            ]),
            BookTable(
              rows: [
                BookTableRow(
                  cells: [
                    BookTableCell(
                      blocks: [BookParagraph(inlines: [BookText('Header 1')])],
                      colSpan: 2,
                    ),
                  ],
                ),
              ],
            ),
          ],
          footnotes: [
            BookFootnote(
              id: 'note_1',
              blocks: [BookParagraph(inlines: [BookText('Текст примечания 1')])],
            ),
          ],
        ),
        resources: const [],
      );

      final fb2Bytes = await Fb2Converter.bookToFb2(richBook);
      final fb2Xml = String.fromCharCodes(fb2Bytes);
      expect(fb2Xml, contains('<epigraph>'));
      expect(fb2Xml, contains('<translator>'));
      expect(fb2Xml, contains('<body name="notes">'));
      expect(fb2Xml, contains('colspan="2"'));
      expect(fb2Xml, contains('email>leo@tolstoy.ru<'));

      final decoded = Fb2Converter.fb2ToBook(fb2Bytes);
      expect(decoded.metadata.publishedAt, isNotNull);
      expect(decoded.metadata.contributors.length, equals(2));
      expect(decoded.metadata.contributorsByRole(BookContributorRole.translator).length, equals(1));
      expect(decoded.content.footnotes.length, equals(1));
      expect(decoded.content.footnotes.first.id, equals('note_1'));

      final epigraph = decoded.content.blocks.firstWhere((b) => b is BookQuote) as BookQuote;
      expect(epigraph.attributes['fb2-type'], equals('epigraph'));

      final table = decoded.content.blocks.firstWhere((b) => b is BookTable) as BookTable;
      expect(table.rows.first.cells.first.colSpan, equals(2));
    });
  });

  group('BookRegistry Tests', () {
    test('Finds correct decoder based on extension and bytes signature', () async {
      final fb2Bytes = await Fb2Converter.bookToFb2(sampleBook);
      final epubBytes = await EpubConverter.bookToEpub(sampleBook);

      final fb2DecoderExt = BookRegistry.findDecoder(fb2Bytes, extension: 'fb2');
      expect(fb2DecoderExt, isA<Fb2Decoder>());

      final fb2DecoderBytes = BookRegistry.findDecoder(fb2Bytes);
      expect(fb2DecoderBytes, isA<Fb2Decoder>());

      final epubDecoderExt = BookRegistry.findDecoder(epubBytes, extension: 'epub');
      expect(epubDecoderExt, isA<EpubDecoder>());

      final epubDecoderBytes = BookRegistry.findDecoder(epubBytes);
      expect(epubDecoderBytes, isA<EpubDecoder>());
    });
  });
}
